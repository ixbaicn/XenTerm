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
  bool _showSftp = false;
  bool _sftpActive = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.background,
      child: Column(
        children: [
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            color: termiusTitleBarColor(Theme.of(context).colorScheme.brightness),
            child: Row(
              children: [
                _tab(context, BootstrapIcons.cloudFill, 'Vault', false, null),
                const SizedBox(width: 8),
                Flexible(
                  child: _tab(
                    context,
                    BootstrapIcons.terminal,
                    widget.host.label,
                    !_sftpActive,
                    widget.onClose,
                    onSelect: () => setState(() => _sftpActive = false),
                    tabKey: const ValueKey('terminal-tab'),
                  ),
                ),
                const SizedBox(width: 12),
                if (_showSftp) ...[
                  Flexible(
                    child: _tab(
                      context,
                      material.Icons.folder_open,
                      widget.host.label,
                      _sftpActive,
                      () => setState(() {
                        _showSftp = false;
                        _sftpActive = false;
                      }),
                      onSelect: () => setState(() => _sftpActive = true),
                      tabKey: const ValueKey('sftp-tab'),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(
                  BootstrapIcons.plus,
                  size: 20,
                  color: scheme.mutedForeground,
                ),
                const Spacer(),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    key: const ValueKey('open-sftp'),
                    onTap: () => setState(() {
                      _showSftp = true;
                      _sftpActive = true;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.card,
                        borderRadius: BorderRadius.circular(TermiusRadius.card),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            material.Icons.folder_open,
                            size: 16,
                            color: scheme.mutedForeground,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'SFTP',
                            style: TextStyle(
                              fontSize: 13,
                              color: scheme.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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
                      child: _sftpActive && _showSftp
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

  Widget _tab(
    BuildContext context,
    IconData icon,
    String label,
    bool active,
    VoidCallback? onClose, {
    VoidCallback? onSelect,
    Key? tabKey,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final tab = Container(
      constraints: BoxConstraints(maxWidth: active ? 340 : 130),
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF153A37) : scheme.card,
        borderRadius: BorderRadius.circular(TermiusRadius.field),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: active ? const Color(0xFF21B568) : scheme.mutedForeground,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                color: active
                    ? const Color(0xFF21B568)
                    : scheme.mutedForeground,
              ),
            ),
          ),
          if (onClose != null) ...[
            const SizedBox(width: 10),
            _toolIcon(context, material.Icons.close, false, onClose),
          ],
        ],
      ),
    );
    if (onSelect == null) return tab;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        key: tabKey,
        behavior: HitTestBehavior.opaque,
        onTap: onSelect,
        child: tab,
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
