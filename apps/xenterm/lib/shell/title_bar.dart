/// The custom titlebar: Termius's 51px tab strip — the WHOLE bar is a drag
/// surface (window_manager's DragToMoveArea; the previous hand-rolled
/// onPanStart only covered two small widgets, which is why the window could
/// not be dragged — a desktop-critical bug), with the pills and window
/// controls as interactive children on top of it.
///
/// Values extracted verbatim (RDe/Q4e styles): container height 51, padding
/// 11px 10px 10px 9px, gap 5, background --dark-grey-1, border-bottom
/// --dark-grey-4; each pill radius 10, padding 6px 10px, 20px icon + label
/// with gap 10, weight 450.
library;

import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:window_manager/window_manager.dart';

import '../data/hosts.dart';
import '../theme/termius_theme.dart';

class TitleBar extends StatelessWidget {
  /// Open terminal sessions, rendered as tabs in the ONE title bar — the
  /// original never stacks a second tab strip inside the terminal.
  final List<Host> openHosts;
  final String? activeHostId;
  final ValueChanged<String>? onSelectHost;
  final ValueChanged<String>? onCloseHost;
  final VoidCallback? onNewTab;
  final bool showSftp;
  final VoidCallback? onToggleSftp;

  const TitleBar({
    super.key,
    this.openHosts = const [],
    this.activeHostId,
    this.onSelectHost,
    this.onCloseHost,
    this.onNewTab,
    this.showSftp = false,
    this.onToggleSftp,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Two sibling layers, not a wrapper: the drag/double-click surface sits
    // BEHIND the interactive row. Previously the whole bar was wrapped in a
    // GestureDetector with onDoubleTap, so every pill/control tap had to wait
    // for the double-tap timeout (~300ms) — the "laggy close button" bug.
    return SizedBox(
      height: 50,
      child: Stack(
        children: [
          Positioned.fill(
            child: DragToMoveArea(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTap: () async {
                  if (await windowManager.isMaximized()) {
                    await windowManager.unmaximize();
                  } else {
                    await windowManager.maximize();
                  }
                },
                child: ColoredBox(
                  color: termiusTitleBarColor(theme.colorScheme.brightness),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(LucideIcons.list,
                      size: 14, color: Color(0xFF8D91A5)),
                ),
                const SizedBox(width: 5),
                _SftpPill(
                  active: showSftp,
                  onTap: openHosts.isEmpty ? null : onToggleSftp,
                ),
                if (openHosts.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 1,
                    height: 22,
                    color: const Color(0xFF32364A),
                  ),
                ],
                for (final host in openHosts) ...[
                  const SizedBox(width: 5),
                  _SessionTab(
                    host: host,
                    active: host.id == activeHostId,
                    onSelect: () => onSelectHost?.call(host.id),
                    onClose: () => onCloseHost?.call(host.id),
                  ),
                ],
                const SizedBox(width: 5),
                _PillButton(
                  icon: LucideIcons.plus,
                  onPressed: onNewTab ?? () {},
                ),
                const Spacer(),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(LucideIcons.bell,
                      size: 15, color: Color(0xFF8D91A5)),
                ),
                const SizedBox(width: 4),
                const _WindowControls(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One open session tab, styled from the original's terminal-tab state:
/// 30px tall, radius 10, 5/8 padding, 14px icon; the active tab uses the
/// terminal accent (green) on --dark-grey-3, inactive tabs stay quiet.
class _SessionTab extends StatefulWidget {
  final Host host;
  final bool active;
  final VoidCallback onSelect;
  final VoidCallback onClose;

  const _SessionTab({
    required this.host,
    required this.active,
    required this.onSelect,
    required this.onClose,
  });

  @override
  State<_SessionTab> createState() => _SessionTabState();
}

class _SessionTabState extends State<_SessionTab> {
  static const _accent = Color(0xFF21B568);
  static const _activeFill = Color(0xFF153A37);

  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = widget.active
        ? _accent
        : (_hovering ? theme.colorScheme.foreground : _muted);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        key: ValueKey('tab-${widget.host.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: widget.onSelect,
        child: AnimatedContainer(
          duration: TermiusMotion.micro,
          curve: TermiusMotion.easeOut,
          height: 36,
          constraints: const BoxConstraints(maxWidth: 240),
          padding: const EdgeInsets.only(left: 10, right: 10),
          decoration: BoxDecoration(
            color: widget.active
                ? _activeFill
                : (_hovering ? const Color(0xFF2C2F3F) : Colors.transparent),
            borderRadius: BorderRadius.circular(TermiusRadius.field),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.active)
                GestureDetector(
                  key: ValueKey('tab-close-${widget.host.id}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onClose,
                  child: Icon(LucideIcons.x, size: 14, color: fg),
                )
              else
                Icon(LucideIcons.x, size: 14, color: fg),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.host.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.normal
                      .copyWith(fontSize: 14, color: fg),
                ),
              ),
              const SizedBox(width: 8),
              Icon(LucideIcons.squareTerminal, size: 15, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}

const _muted = Color(0xFF8D91A5);

/// The SFTP tab from the original: a filled --dark-grey-3 chip with the
/// folder icon and label; it toggles the active terminal's SFTP view.
class _SftpPill extends StatefulWidget {
  final bool active;
  final VoidCallback? onTap;

  const _SftpPill({required this.active, this.onTap});

  @override
  State<_SftpPill> createState() => _SftpPillState();
}

class _SftpPillState extends State<_SftpPill> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = widget.active
        ? theme.colorScheme.foreground
        : (widget.onTap == null
            ? const Color(0xFF5A5E73)
            : (_hovering ? theme.colorScheme.foreground : _muted));
    return MouseRegion(
      cursor: widget.onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        key: const ValueKey('sftp-tab'),
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: TermiusMotion.micro,
          curve: TermiusMotion.easeOut,
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF202436),
            borderRadius: BorderRadius.circular(TermiusRadius.field),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.folderOpen, size: 15, color: fg),
              const SizedBox(width: 8),
              Text('SFTP',
                  style: theme.typography.normal
                      .copyWith(fontSize: 14, color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A square icon-only pill (the new-tab +).
class _PillButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _PillButton({required this.icon, required this.onPressed});

  @override
  State<_PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<_PillButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: TermiusMotion.micro,
          curve: TermiusMotion.easeOut,
          height: 30,
          width: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color:
                _hovering ? theme.colorScheme.secondary : Colors.transparent,
            borderRadius: BorderRadius.circular(TermiusRadius.field),
          ),
          child: Icon(widget.icon,
              size: 14, color: theme.colorScheme.mutedForeground),
        ),
      ),
    );
  }
}

/// min / max / close, the Windows trio, drawn — the frame is hidden.
class _WindowControls extends StatelessWidget {
  const _WindowControls();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ControlButton(
          icon: LucideIcons.minus,
          onTap: windowManager.minimize,
        ),
        _ControlButton(
          icon: LucideIcons.square,
          onTap: () async {
            if (await windowManager.isMaximized()) {
              await windowManager.unmaximize();
            } else {
              await windowManager.maximize();
            }
          },
        ),
        _ControlButton(
          icon: LucideIcons.x,
          hoverColor: const Color(0xFFE81123), // Windows close red
          onTap: windowManager.close,
        ),
      ],
    );
  }
}

class _ControlButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? hoverColor;

  const _ControlButton({
    required this.icon,
    required this.onTap,
    this.hoverColor,
  });

  @override
  State<_ControlButton> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<_ControlButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: SizedBox(
          width: 46,
          height: 50,
          child: Icon(
            widget.icon,
            size: 14,
            color: _hovering
                ? (widget.hoverColor != null
                    ? Colors.white
                    : theme.colorScheme.foreground)
                : theme.colorScheme.mutedForeground,
          ),
        ),
      ),
    );
  }
}
