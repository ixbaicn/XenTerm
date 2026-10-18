import 'package:flutter/material.dart' as material;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../data/hosts.dart';
import '../../theme/termius_theme.dart';
import '../../theme/app_fonts.dart';
import 'sftp_preview.dart';
import 'terminal_tools_panel.dart';

/// A connection workspace preview. TODO(ffi/ssh): replace the placeholder
/// terminal with a stream from xenterm-bridge, wire keyboard/input/resize and
/// drive tab status from the SSH session lifecycle. No network call occurs here.
class TerminalScreen extends StatefulWidget {
  final Host host;
  final VoidCallback onClose;
  final AppFonts fonts;

  const TerminalScreen({
    super.key,
    required this.host,
    required this.onClose,
    required this.fonts,
  });

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  bool _showTools = true;
  bool _sftpActive = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.background,
      child: Column(
        children: [
          // In-pane controls only: Terminal/SFTP view switch + tools panel.
          // Session tabs live in the title bar (the original's single strip).
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                const Spacer(),
                _viewChip(
                  context,
                  material.Icons.terminal,
                  'Terminal',
                  !_sftpActive,
                  const ValueKey('terminal-tab'),
                  () => setState(() => _sftpActive = false),
                ),
                const SizedBox(width: 6),
                _viewChip(
                  context,
                  material.Icons.folder_open,
                  'SFTP',
                  _sftpActive,
                  const ValueKey('sftp-tab'),
                  () => setState(() => _sftpActive = true),
                ),
                const SizedBox(width: 8),
                _toolIcon(
                  context,
                  material.Icons.view_sidebar_outlined,
                  _showTools,
                  () => setState(() => _showTools = !_showTools),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final toolsWidth = constraints.maxWidth < 900 ? 300.0 : 390.0;
                return Row(
                  children: [
                    Expanded(
                      child: _sftpActive
                          ? SftpPreview(host: widget.host)
                          : Container(
                              color: termiusTitleBarColor(Theme.of(context).colorScheme.brightness),
                              padding: const EdgeInsets.all(18),
                              alignment: Alignment.topLeft,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${widget.host.username}@${widget.host.address}',
                                    style: TextStyle(
                                      fontFamily:
                                          widget.fonts.terminalFamily.isEmpty
                                          ? 'monospace'
                                          : widget.fonts.terminalFamily,
                                      fontSize: widget.fonts.terminalSize,
                                      color: Color(0xFF21B568),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'SSH 连接预览 · 尚未连接到服务器',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: scheme.mutedForeground,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '待接入 Rust 会话流与终端输入',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: scheme.mutedForeground,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                    if (_showTools)
                      SizedBox(
                        width: toolsWidth,
                        child: TerminalToolsPanel(fonts: widget.fonts),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewChip(
    BuildContext context,
    IconData icon,
    String label,
    bool selected,
    Key key,
    VoidCallback onTap,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final fg = selected ? scheme.foreground : scheme.mutedForeground;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        key: key,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF3E4257) : Colors.transparent,
            borderRadius: BorderRadius.circular(TermiusRadius.card),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(fontSize: 12, color: fg)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolIcon(
    BuildContext context,
    IconData icon,
    bool selected,
    VoidCallback onTap,
  ) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF153A37) : Colors.transparent,
            borderRadius: BorderRadius.circular(TermiusRadius.card),
          ),
          child: Icon(
            icon,
            size: 18,
            color: selected
                ? const Color(0xFF21B568)
                : Theme.of(context).colorScheme.mutedForeground,
          ),
        ),
      ),
    );
  }
}
