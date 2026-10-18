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

import '../theme/termius_theme.dart';

class TitleBar extends StatelessWidget {
  const TitleBar({super.key});

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
                  child: Icon(BootstrapIcons.list,
                      size: 14, color: Color(0xFF8D91A5)),
                ),
                const SizedBox(width: 5),
                const _TitlePill(
                  icon: Icon(BootstrapIcons.safe,
                      size: 15, color: Color(0xFF8D91A5)),
                  label: 'Vaults',
                  filled: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(BootstrapIcons.cloudFill,
                          size: 13, color: Color(0xFF8D91A5)),
                      SizedBox(width: 6),
                      Icon(BootstrapIcons.caretDownFill,
                          size: 9, color: Color(0xFF8D91A5)),
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                const _TitlePill(
                  icon: Icon(BootstrapIcons.folder2Open,
                      size: 15, color: Color(0xFF8D91A5)),
                  label: 'SFTP',
                ),
                const SizedBox(width: 5),
                _PillButton(
                  icon: BootstrapIcons.plus,
                  onPressed: () {},
                ),
                const Spacer(),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(BootstrapIcons.bell,
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

/// One titlebar tab pill: icon + label, gap 8, height 30, radius 10. The
/// active tab (Vaults) is a filled --dark-grey-4 chip; the inactive one is
/// transparent until hover.
class _TitlePill extends StatefulWidget {
  final Widget icon;
  final String label;
  final Widget? trailing;
  final bool filled;

  const _TitlePill({
    required this.icon,
    required this.label,
    this.trailing,
    this.filled = false,
  });

  @override
  State<_TitlePill> createState() => _TitlePillState();
}

class _TitlePillState extends State<_TitlePill> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = _hovering
        ? theme.colorScheme.foreground
        : theme.colorScheme.mutedForeground;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: AnimatedContainer(
          duration: TermiusMotion.micro,
          curve: TermiusMotion.easeOut,
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: widget.filled
                ? const Color(0xFF2C2F3F)
                : (_hovering ? const Color(0xFF2C2F3F) : Colors.transparent),
            borderRadius: BorderRadius.circular(TermiusRadius.field),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              widget.icon,
              const SizedBox(width: 8),
              Text(widget.label,
                  style: theme.typography.normal
                      .copyWith(fontSize: 14, color: fg)),
              if (widget.trailing != null) ...[
                const SizedBox(width: 8),
                widget.trailing!,
              ],
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
          icon: BootstrapIcons.dashLg,
          onTap: windowManager.minimize,
        ),
        _ControlButton(
          icon: BootstrapIcons.square,
          onTap: () async {
            if (await windowManager.isMaximized()) {
              await windowManager.unmaximize();
            } else {
              await windowManager.maximize();
            }
          },
        ),
        _ControlButton(
          icon: BootstrapIcons.xLg,
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
