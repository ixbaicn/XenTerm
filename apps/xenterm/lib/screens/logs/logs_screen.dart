/// Logs — real session transcripts recorded by the core when "Save session
/// logs" is enabled in Settings. Rows open a read-only viewer; deletion removes
/// the JSONL file. No plan/account content exists in this product.
library;

import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../bridge/native_bridge.dart';
import '../../widgets/lucide_extra_icons.dart';
import '../../widgets/toolbar.dart';

typedef LogLoader = Future<List<SessionLogEntry>> Function();
typedef LogReader = Future<SessionLogContent> Function(String file);
typedef LogDeleter = Future<CoreWriteResult> Function(String file);

class LogsScreen extends StatefulWidget {
  final LogLoader? loadLogs;
  final LogReader? readLog;
  final LogDeleter? deleteLog;

  const LogsScreen({super.key, this.loadLogs, this.readLog, this.deleteLog});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  List<SessionLogEntry> _logs = const [];
  bool _loading = true;
  String? _error;
  SessionLogEntry? _open;
  SessionLogContent? _content;
  bool _reading = false;
  bool _confirmClear = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final logs = await (widget.loadLogs ?? loadSessionLogsFromCore)();
      if (!mounted) return;
      setState(() {
        _logs = logs;
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

  Future<void> _openLog(SessionLogEntry entry) async {
    setState(() {
      _open = entry;
      _content = null;
      _reading = true;
    });
    try {
      final content = await (widget.readLog ?? readSessionLogFromCore)(
        entry.file,
      );
      if (!mounted || _open?.file != entry.file) return;
      setState(() {
        _content = content;
        _reading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _reading = false;
        _error = error is NativeBridgeError ? error.message : '$error';
      });
    }
  }

  Future<void> _delete(SessionLogEntry entry) async {
    try {
      final result = await (widget.deleteLog ?? deleteSessionLogFromCore)(
        entry.file,
      );
      if (!result.ok) {
        if (!mounted) return;
        setState(() => _error = result.error ?? 'Could not delete the log');
        return;
      }
      if (_open?.file == entry.file) {
        setState(() {
          _open = null;
          _content = null;
        });
      }
      await _reload(silent: true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    }
  }

  Future<void> _deleteAll() async {
    final entries = [..._logs];
    for (final entry in entries) {
      try {
        await (widget.deleteLog ?? deleteSessionLogFromCore)(entry.file);
      } catch (_) {
        // Keep deleting the rest; the reload below surfaces what is left.
      }
    }
    if (!mounted) return;
    setState(() {
      _confirmClear = false;
      _open = null;
      _content = null;
    });
    await _reload(silent: true);
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
                padding: const EdgeInsets.fromLTRB(34, 18, 34, 0),
                child: Row(
                  children: [
                    Text(
                      'Session logs',
                      style: theme.typography.semiBold.copyWith(
                        fontSize: 16,
                        color: theme.colorScheme.foreground,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_logs.length}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.mutedForeground,
                      ),
                    ),
                    const Spacer(),
                    IconToggleButton(
                      icon: LucideIcons.refreshCw,
                      onPressed: () => _reload(),
                    ),
                    if (_logs.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      IconToggleButton(
                        key: const ValueKey('logs-clear'),
                        icon: LucideIcons.trash2,
                        onPressed: () =>
                            setState(() => _confirmClear = !_confirmClear),
                      ),
                    ],
                  ],
                ),
              ),
              if (_confirmClear)
                Container(
                  margin: const EdgeInsets.fromLTRB(34, 10, 34, 0),
                  padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1B1B),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.triangleAlert,
                        size: 16,
                        color: Color(0xFFE5484D),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Delete all ${_logs.length} session logs? This cannot '
                          'be undone.',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.foreground,
                          ),
                        ),
                      ),
                      Button(
                        key: const ValueKey('logs-clear-confirm'),
                        style: const ButtonStyle.primary(),
                        onPressed: _deleteAll,
                        child: const Text('Delete all'),
                      ),
                      const SizedBox(width: 6),
                      GhostButton(
                        onPressed: () => setState(() => _confirmClear = false),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 20, color: Color(0xFF1F1F1F)),
              Expanded(child: _body(theme)),
            ],
          ),
        ),
        if (_open != null)
          SizedBox(
            width: 560,
            child: _LogViewer(
              entry: _open!,
              content: _content,
              reading: _reading,
              onDelete: () => _delete(_open!),
              onClose: () => setState(() {
                _open = null;
                _content = null;
              }),
            ),
          ),
      ],
    );
  }

  Widget _body(ThemeData theme) {
    if (_loading) {
      return const Center(
        child: Text(
          'Loading session logs…',
          style: TextStyle(color: Color(0xFFA6A6A6)),
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
              style: const TextStyle(color: Color(0xFFA6A6A6)),
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
    if (_logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipboardClockIcon(
              size: 30,
              color: theme.colorScheme.mutedForeground,
            ),
            const SizedBox(height: 10),
            Text(
              'No session logs yet',
              style: theme.typography.semiBold.copyWith(
                fontSize: 15,
                color: theme.colorScheme.foreground,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Enable “Save session logs” in Settings → Logs to record new sessions.',
              textAlign: TextAlign.center,
              style: theme.typography.normal.copyWith(
                fontSize: 13,
                color: theme.colorScheme.mutedForeground,
              ),
            ),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 4),
      children: [
        for (final entry in _logs)
          _LogRow(
            key: ValueKey('log-${entry.file}'),
            entry: entry,
            selected: _open?.file == entry.file,
            onTap: () => _openLog(entry),
            onDelete: () => _delete(entry),
          ),
      ],
    );
  }
}

class _LogRow extends StatefulWidget {
  final SessionLogEntry entry;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _LogRow({
    super.key,
    required this.entry,
    required this.selected,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<_LogRow> createState() => _LogRowState();
}

class _LogRowState extends State<_LogRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final background = widget.selected
        ? const Color(0xFF262626)
        : _hover
        ? const Color(0xFF1B1B1B)
        : const Color(0xFF111111);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 56,
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(entry.started),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFD4D4D4),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        entry.name.isEmpty ? entry.host : entry.name,
                        if (entry.user.isNotEmpty) entry.user,
                        _formatSize(entry.size),
                      ].join('  ·  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFFA6A6A6),
                      ),
                    ),
                  ],
                ),
              ),
              if (_hover)
                Tooltip(
                  tooltip: (_) => const Text('Delete log'),
                  child: GestureDetector(
                    key: ValueKey('log-row-delete-${entry.file}'),
                    onTap: widget.onDelete,
                    child: Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      child: const Icon(
                        LucideIcons.trash2,
                        size: 14,
                        color: Color(0xFFE5484D),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}';
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _LogViewer extends StatelessWidget {
  final SessionLogEntry entry;
  final SessionLogContent? content;
  final bool reading;
  final VoidCallback onDelete;
  final VoidCallback onClose;

  const _LogViewer({
    required this.entry,
    required this.content,
    required this.reading,
    required this.onDelete,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        border: Border(left: BorderSide(color: Color(0xFF1F1F1F))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF1F1F1F))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.name.isEmpty ? entry.host : entry.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.semiBold.copyWith(
                          fontSize: 15,
                          color: theme.colorScheme.foreground,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_LogRowState._formatDate(entry.started)}'
                        '${entry.user.isEmpty ? '' : '  ·  ${entry.user}'}'
                        '  ·  ${_LogRowState._formatSize(entry.size)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: theme.colorScheme.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                _ViewerAction(
                  key: const ValueKey('log-copy'),
                  icon: LucideIcons.copy,
                  onPressed: content == null
                      ? null
                      : () => Clipboard.setData(
                          ClipboardData(text: content!.text),
                        ),
                ),
                _ViewerAction(
                  key: const ValueKey('log-delete'),
                  icon: LucideIcons.trash2,
                  color: const Color(0xFFE5484D),
                  onPressed: onDelete,
                ),
                _ViewerAction(icon: LucideIcons.x, onPressed: onClose),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF151515),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF1F1F1F)),
                ),
                child: reading
                    ? const Center(
                        child: Text(
                          'Opening transcript…',
                          style: TextStyle(color: Color(0xFFA6A6A6)),
                        ),
                      )
                    : (content?.text.isEmpty ?? true)
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            content?.closeReason == null ||
                                    content!.closeReason!.isEmpty
                                ? 'This session produced no terminal output.'
                                : 'Session closed: ${content!.closeReason}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFFA6A6A6),
                            ),
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          content!.text,
                          style: const TextStyle(
                            fontFamily: 'Consolas',
                            fontFamilyFallback: ['Menlo', 'Courier New'],
                            fontSize: 12.5,
                            height: 1.5,
                            color: Color(0xFFDDDDDD),
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewerAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;

  const _ViewerAction({
    super.key,
    required this.icon,
    required this.onPressed,
    this.color = const Color(0xFFD4D4D4),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 30,
        height: 30,
        margin: const EdgeInsets.only(left: 4),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 15,
          color: onPressed == null ? const Color(0xFF6E6E6E) : color,
        ),
      ),
    );
  }
}
