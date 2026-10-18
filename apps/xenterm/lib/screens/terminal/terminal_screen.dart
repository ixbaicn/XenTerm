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
  final AppFonts fonts;
  /// SFTP view is toggled from the title bar's SFTP tab.
  final bool showSftp;

  const TerminalScreen({
    super.key,
    required this.host,
    required this.fonts,
    this.showSftp = false,
  });

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.background,
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final toolsWidth = constraints.maxWidth < 900 ? 300.0 : 390.0;
                return Row(
                  children: [
                    Expanded(
                      child: widget.showSftp
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

}
