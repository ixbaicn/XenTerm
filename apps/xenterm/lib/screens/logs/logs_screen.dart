/// Logs — real session transcripts recorded by the core when "Save session
/// logs" is enabled in Settings. Rows open a read-only viewer; deletion removes
/// the JSONL file. No plan/account content exists in this product.
library;

import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../bridge/native_bridge.dart';
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
                    _headerCell(
                      theme,
                      'Date',
                      trailing: LucideIcons.chevronDown,
                      width: 190,
                    ),
                    _headerCell(theme, 'User', width: 220),
                    _headerCell(theme, 'Host', width: 240),
                    _headerCell(theme, 'Size'),
                    const Spacer(),
                    IconToggleButton(
                      icon: LucideIcons.refreshCw,
                      onPressed: () => _reload(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 20, color: Color(0xFF262A3D)),
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

  Widget _headerCell(
    ThemeData theme,
    String text, {
    IconData? trailing,
    double? width,
  }) {
    return SizedBox(
      width: width,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: theme.typography.normal.copyWith(
              fontSize: 14,
              color: theme.colorScheme.foreground,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            Icon(trailing, size: 12, color: theme.colorScheme.mutedForeground),
          ],
        ],
      ),
    );
  }

  Widget _body(ThemeData theme) {
    if (_loading) {
      return const Center(
        child: Text(
          'Loading session logs…',
          style: TextStyle(color: Color(0xFF8D91A5)),
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
    if (_logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.scrollText,
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
          ),
      ],
    );
  }
}

class _LogRow extends StatefulWidget {
  final SessionLogEntry entry;
  final bool selected;
  final VoidCallback onTap;

  const _LogRow({
    super.key,
    required this.entry,
    required this.selected,
    required this.onTap,
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
        ? const Color(0xFF2C3046)
        : _hover
        ? const Color(0xFF282B3D)
        : const Color(0xFF1D2033);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 46,
          color: background,
          padding: const EdgeInsets.symmetric(horizontal: 0),
          child: Row(
            children: [
              SizedBox(
                width: 190,
                child: Text(
                  _formatDate(entry.started),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFC7CBD6),
                  ),
                ),
              ),
              SizedBox(
                width: 220,
                child: Text(
                  entry.user.isEmpty ? '—' : entry.user,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFC7CBD6),
                  ),
                ),
              ),
              SizedBox(
                width: 240,
                child: Text(
                  entry.name.isEmpty ? entry.host : entry.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFC7CBD6),
                  ),
                ),
              ),
              Text(
                _formatSize(entry.size),
                style: const TextStyle(fontSize: 13, color: Color(0xFF8D91A5)),
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
        color: Color(0xFF1D2033),
        border: Border(left: BorderSide(color: Color(0xFF262A3D))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF262A3D))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    entry.name.isEmpty ? entry.host : entry.name,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.semiBold.copyWith(
                      fontSize: 15,
                      color: theme.colorScheme.foreground,
                    ),
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
            child: reading
                ? const Center(
                    child: Text(
                      'Opening transcript…',
                      style: TextStyle(color: Color(0xFF8D91A5)),
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
                          color: Color(0xFF8D91A5),
                        ),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      content!.text,
                      style: const TextStyle(
                        fontFamily: 'Consolas',
                        fontFamilyFallback: ['Menlo', 'Courier New'],
                        fontSize: 12.5,
                        height: 1.4,
                        color: Color(0xFFD5DDE0),
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
    this.color = const Color(0xFFC7CBD6),
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
          color: onPressed == null ? const Color(0xFF5A5F73) : color,
        ),
      ),
    );
  }
}
