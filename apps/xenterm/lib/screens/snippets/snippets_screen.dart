/// Snippets — the core's saved quick commands, with real create/edit/delete
/// and one-click execution in the active terminal. No fixture data: the list
/// loads from `ConfigStore` through the FFI bridge and every action writes back
/// to `sessions.db`.
library;

import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../bridge/native_bridge.dart';
import '../../theme/termius_theme.dart';
import '../../widgets/toolbar.dart';

typedef SnippetLoader = Future<List<QuickCommand>> Function();
typedef SnippetSaver = Future<CoreWriteResult> Function({
  required int index,
  required String name,
  required String command,
  required String group,
  required bool sendEnter,
});
typedef SnippetDeleter = Future<CoreWriteResult> Function(int index);

class SnippetsScreen extends StatefulWidget {
  final SnippetLoader? loadSnippets;
  final SnippetSaver? saveSnippet;
  final SnippetDeleter? deleteSnippet;

  /// Sends the snippet to the active terminal (RootShell wires this).
  final void Function(QuickCommand snippet)? onRun;

  const SnippetsScreen({
    super.key,
    this.loadSnippets,
    this.saveSnippet,
    this.deleteSnippet,
    this.onRun,
  });

  @override
  State<SnippetsScreen> createState() => _SnippetsScreenState();
}

class _SnippetsScreenState extends State<SnippetsScreen> {
  List<QuickCommand> _snippets = const [];
  bool _loading = true;
  String? _error;
  String? _notice;
  String _query = '';
  bool _searching = false;
  QuickCommand? _editing; // null with _drawerOpen => new snippet
  bool _drawerOpen = false;
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final snippets =
          await (widget.loadSnippets ?? loadQuickCommandsFromCore)();
      if (!mounted) return;
      setState(() {
        _snippets = snippets;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is NativeBridgeError ? error.message : '$error';
      });
    }
  }

  List<QuickCommand> get _filtered {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _snippets;
    return _snippets
        .where(
          (s) =>
              s.name.toLowerCase().contains(query) ||
              s.command.toLowerCase().contains(query) ||
              s.group.toLowerCase().contains(query),
        )
        .toList();
  }

  Future<String?> _save({
    required int index,
    required String name,
    required String command,
    required String group,
    required bool sendEnter,
  }) async {
    try {
      final result = await (widget.saveSnippet ?? saveQuickCommandToCore)(
        index: index,
        name: name,
        command: command,
        group: group,
        sendEnter: sendEnter,
      );
      if (!result.ok) return result.error ?? 'Save failed';
      await _reload(silent: true);
      return null;
    } catch (error) {
      return '$error';
    }
  }

  Future<String?> _delete(QuickCommand snippet) async {
    try {
      final result = await (widget.deleteSnippet ?? deleteQuickCommandFromCore)(
        snippet.index,
      );
      if (!result.ok) return result.error ?? 'Delete failed';
      _closeDrawer();
      await _reload(silent: true);
      return null;
    } catch (error) {
      return '$error';
    }
  }

  void _openNew() {
    setState(() {
      _editing = null;
      _drawerOpen = true;
    });
  }

  void _openEdit(QuickCommand snippet) {
    setState(() {
      _editing = snippet;
      _drawerOpen = true;
    });
  }

  void _closeDrawer() {
    setState(() {
      _drawerOpen = false;
      _editing = null;
    });
  }

  void _run(QuickCommand snippet) {
    final run = widget.onRun;
    if (run == null) {
      setState(() => _notice = 'Open a terminal first to run snippets.');
      return;
    }
    setState(() => _notice = null);
    run(snippet);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Row(
                  children: [
                    SplitButton(
                      label: 'New snippet',
                      icon: LucideIcons.plus,
                      onPressed: _openNew,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        IconToggleButton(
                          icon: LucideIcons.search,
                          onPressed: () => setState(() {
                            _searching = !_searching;
                            if (!_searching) {
                              _search.clear();
                              _query = '';
                            }
                          }),
                        ),
                        const SizedBox(width: 6),
                        IconToggleButton(
                          icon: LucideIcons.refreshCw,
                          onPressed: () => _reload(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_searching)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: TextField(
                    key: const ValueKey('snippet-search'),
                    controller: _search,
                    autofocus: true,
                    onChanged: (value) => setState(() => _query = value),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF282B3D),
                      borderRadius: BorderRadius.circular(TermiusRadius.field),
                    ),
                    placeholder: const Text(
                      'Search snippets',
                      style: TextStyle(fontSize: 13, color: Color(0xFF8D91A5)),
                    ),
                  ),
                ),
              if (_notice != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x33F8AA4B),
                      borderRadius: BorderRadius.circular(TermiusRadius.field),
                    ),
                    child: Text(
                      _notice!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFF8AA4B),
                      ),
                    ),
                  ),
                ),
              const SectionTitle(text: 'Snippets'),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: _body(theme),
                ),
              ),
            ],
          ),
        ),
        ClipRect(
          child: AnimatedContainer(
            duration: TermiusMotion.micro,
            curve: TermiusMotion.easeOut,
            width: _drawerOpen ? 340 : 0,
            child: _drawerOpen
                ? OverflowBox(
                    alignment: Alignment.centerRight,
                    minWidth: 340,
                    maxWidth: 340,
                    child: SnippetEditor(
                      key: ValueKey(_editing?.index ?? -1),
                      snippet: _editing,
                      onSave: _save,
                      onDelete: _editing == null ? null : _delete,
                      onClose: _closeDrawer,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  Widget _body(ThemeData theme) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Text(
            'Loading snippets…',
            style: TextStyle(color: Color(0xFF8D91A5)),
          ),
        ),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF8D91A5)),
            ),
            const SizedBox(height: 12),
            Button(
              style: const ButtonStyle.outline(),
              onPressed: () => _reload(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    final snippets = _filtered;
    if (snippets.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              LucideIcons.braces,
              size: 30,
              color: theme.colorScheme.mutedForeground,
            ),
            const SizedBox(height: 10),
            Text(
              _snippets.isEmpty ? 'No snippets yet' : 'No matches',
              style: theme.typography.semiBold.copyWith(
                fontSize: 15,
                color: theme.colorScheme.foreground,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _snippets.isEmpty
                  ? 'Save a command here to run it in one click.'
                  : 'Try a different search.',
              style: theme.typography.normal.copyWith(
                fontSize: 13,
                color: theme.colorScheme.mutedForeground,
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        for (final snippet in snippets)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _SnippetCard(
              snippet: snippet,
              onRun: () => _run(snippet),
              onEdit: () => _openEdit(snippet),
              onDelete: () => _delete(snippet),
            ),
          ),
      ],
    );
  }
}

class _SnippetCard extends StatefulWidget {
  final QuickCommand snippet;
  final VoidCallback onRun;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SnippetCard({
    required this.snippet,
    required this.onRun,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_SnippetCard> createState() => _SnippetCardState();
}

class _SnippetCardState extends State<_SnippetCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onRun,
        child: Container(
          key: ValueKey('snippet-${widget.snippet.index}'),
          height: 76,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: _hover ? const Color(0xFF32364A) : const Color(0xFF282B3D),
            borderRadius: BorderRadius.circular(TermiusRadius.cardLarge),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF202436),
                  borderRadius: BorderRadius.circular(TermiusRadius.menu),
                ),
                child: const Icon(
                  LucideIcons.terminal,
                  size: 20,
                  color: Color(0xFF21B568),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.snippet.name,
                            overflow: TextOverflow.ellipsis,
                            style: theme.typography.semiBold.copyWith(
                              fontSize: 15,
                              color: theme.colorScheme.foreground,
                            ),
                          ),
                        ),
                        if (widget.snippet.group.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF202436),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              widget.snippet.group,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF8D91A5),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.snippet.command,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Consolas',
                        fontFamilyFallback: ['Menlo', 'Courier New'],
                        fontSize: 12.5,
                        color: Color(0xFF8D91A5),
                      ),
                    ),
                  ],
                ),
              ),
              if (_hover) ...[
                _CardAction(
                  icon: LucideIcons.play,
                  tooltip: 'Run',
                  onTap: widget.onRun,
                ),
                _CardAction(
                  icon: LucideIcons.pencil,
                  tooltip: 'Edit',
                  onTap: widget.onEdit,
                ),
                _CardAction(
                  icon: LucideIcons.trash2,
                  tooltip: 'Delete',
                  onTap: widget.onDelete,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _CardAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      tooltip: (_) => Text(tooltip),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          margin: const EdgeInsets.only(left: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF202436),
            borderRadius: BorderRadius.circular(TermiusRadius.menu),
          ),
          child: Icon(icon, size: 14, color: const Color(0xFFC7CBD6)),
        ),
      ),
    );
  }
}

/// The 340px editor drawer: name, group, command, send-enter, save/delete.
class SnippetEditor extends StatefulWidget {
  final QuickCommand? snippet;
  final Future<String?> Function({
    required int index,
    required String name,
    required String command,
    required String group,
    required bool sendEnter,
  })
  onSave;
  final Future<String?> Function(QuickCommand snippet)? onDelete;
  final VoidCallback onClose;

  const SnippetEditor({
    super.key,
    required this.snippet,
    required this.onSave,
    required this.onDelete,
    required this.onClose,
  });

  @override
  State<SnippetEditor> createState() => _SnippetEditorState();
}

class _SnippetEditorState extends State<SnippetEditor> {
  late final TextEditingController _name = TextEditingController(
    text: widget.snippet?.name ?? '',
  );
  late final TextEditingController _group = TextEditingController(
    text: widget.snippet?.group ?? '',
  );
  late final TextEditingController _command = TextEditingController(
    text: widget.snippet?.command ?? '',
  );
  late bool _sendEnter = widget.snippet?.sendEnter ?? true;
  bool _saving = false;
  bool _deleting = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _group.dispose();
    _command.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_command.text.trim().isEmpty) {
      setState(() => _error = 'The command cannot be empty.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await widget.onSave(
      index: widget.snippet?.index ?? -1,
      name: _name.text.trim(),
      command: _command.text.trim(),
      group: _group.text.trim(),
      sendEnter: _sendEnter,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      setState(() => _error = error);
    } else {
      widget.onClose();
    }
  }

  Future<void> _delete() async {
    final delete = widget.onDelete;
    if (delete == null) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    final error = await delete(widget.snippet!);
    if (!mounted) return;
    setState(() => _deleting = false);
    if (error != null) setState(() => _error = error);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF282B3D),
        borderRadius: BorderRadius.circular(TermiusRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF32364A))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.snippet == null ? 'New snippet' : 'Snippet',
                    style: theme.typography.semiBold.copyWith(
                      fontSize: 16,
                      color: const Color(0xFF8D91A5),
                    ),
                  ),
                ),
                if (widget.snippet != null)
                  _HeaderButton(
                    key: const ValueKey('snippet-delete'),
                    icon: LucideIcons.trash2,
                    destructive: true,
                    busy: _deleting,
                    onTap: _delete,
                  ),
                const SizedBox(width: 6),
                _HeaderButton(
                  key: const ValueKey('snippet-save'),
                  icon: LucideIcons.check,
                  busy: _saving,
                  onTap: _save,
                ),
                const SizedBox(width: 6),
                _HeaderButton(icon: LucideIcons.x, onTap: widget.onClose),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(15, 15, 15, 15),
              children: [
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0x33E5484D),
                      borderRadius: BorderRadius.circular(TermiusRadius.field),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFFF8A8D),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                _Field(
                  key: const ValueKey('snippet-name'),
                  controller: _name,
                  placeholder: 'Name',
                  autofocus: true,
                ),
                const SizedBox(height: 10),
                _Field(
                  key: const ValueKey('snippet-group'),
                  controller: _group,
                  placeholder: 'Group (optional)',
                ),
                const SizedBox(height: 10),
                _Field(
                  key: const ValueKey('snippet-command'),
                  controller: _command,
                  placeholder: 'Command',
                  multiline: true,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Press Enter after running',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFFC7CBD6),
                        ),
                      ),
                    ),
                    Switch(
                      key: const ValueKey('snippet-send-enter'),
                      value: _sendEnter,
                      onChanged: (value) => setState(() => _sendEnter = value),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String placeholder;
  final bool multiline;
  final bool autofocus;

  const _Field({
    super.key,
    required this.controller,
    required this.placeholder,
    this.multiline = false,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      maxLines: multiline ? 8 : 1,
      minLines: multiline ? 3 : 1,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF202436),
        borderRadius: BorderRadius.circular(TermiusRadius.field),
      ),
      placeholder: Text(
        placeholder,
        style: const TextStyle(fontSize: 13, color: Color(0xFF6E7388)),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool destructive;
  final bool busy;

  const _HeaderButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.destructive = false,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF32364A),
          borderRadius: BorderRadius.circular(TermiusRadius.menu),
        ),
        child: busy
            ? const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              )
            : Icon(
                icon,
                size: 14,
                color: destructive
                    ? const Color(0xFFE5484D)
                    : const Color(0xFFC7CBD6),
              ),
      ),
    );
  }
}
