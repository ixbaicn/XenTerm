import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../data/hosts.dart';
import '../../theme/termius_theme.dart';
import 'terminal_tools_panel.dart';

/// A connection workspace preview. TODO(ffi/ssh): replace the placeholder
/// terminal with a stream from xenterm-bridge, wire keyboard/input/resize and
/// drive tab status from the SSH session lifecycle. No network call occurs here.
class TerminalScreen extends StatefulWidget {
  final Host host;
  final VoidCallback onClose;

  const TerminalScreen({super.key, required this.host, required this.onClose});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  bool _showTools = true;

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
            color: const Color(0xFF141729),
            child: Row(
              children: [
                _tab(context, BootstrapIcons.cloudFill, 'Vault', false, null),
                const SizedBox(width: 8),
                Flexible(
                  child: _tab(
                    context,
                    BootstrapIcons.terminal,
                    widget.host.label,
                    true,
                    widget.onClose,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  BootstrapIcons.plus,
                  size: 20,
                  color: scheme.mutedForeground,
                ),
                const Spacer(),
                _toolIcon(
                  context,
                  BootstrapIcons.layoutSidebarInsetReverse,
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
                      child: Container(
                        color: const Color(0xFF141729),
                        padding: const EdgeInsets.all(18),
                        alignment: Alignment.topLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${widget.host.username}@${widget.host.address}',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 15,
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
                        child: const TerminalToolsPanel(),
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
    VoidCallback? onClose,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
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
            _toolIcon(context, BootstrapIcons.x, false, onClose),
          ],
        ],
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
