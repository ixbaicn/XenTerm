/// The custom titlebar: Termius's 51px tab strip — drag region, hamburger,
/// the Vaults pill, the SFTP pill, the new-tab button, and the window
/// controls on the right.
///
/// Values extracted verbatim (RDe/Q4e styles): container height 51, padding
/// 11px 10px 10px 9px, gap 5, background --dark-grey-1, border-bottom
/// --dark-grey-4; each pill radius 10, padding 6px 10px, grid 20px icon +
/// label with gap 10, weight 450.
library;

import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:window_manager/window_manager.dart';

import '../theme/termius_theme.dart';

class TitleBar extends StatelessWidget {
  const TitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 51,
      decoration: BoxDecoration(
        color: const Color(0xFF141729), // --dark-grey-1
        border: Border(
            bottom: BorderSide(color: theme.colorScheme.secondary)), // dg-4
      ),
      padding: const EdgeInsets.fromLTRB(9, 11, 0, 10),
      child: Row(
        children: [
          // The app mark, where Termius's hamburger sits.
          const _DragArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(BootstrapIcons.list,
                  size: 14, color: Color(0xFF8D91A5)), // dark-grey-7
            ),
          ),
          const SizedBox(width: 5),
          _TitlePill(
            icon: const Icon(BootstrapIcons.cloudFill,
                size: 13, color: Color(0xFF8D91A5)),
            label: 'Vaults',
            trailing: const Icon(BootstrapIcons.caretDownFill,
                size: 9, color: Color(0xFF8D91A5)),
          ),
          const SizedBox(width: 5),
          _TitlePill(
            icon: const Icon(BootstrapIcons.folder2Open,
                size: 13, color: Color(0xFF8D91A5)),
            label: 'SFTP',
          ),
          const SizedBox(width: 5),
          _DragArea(
            child: GhostButton(
              density: ButtonDensity.compact,
              onPressed: () {},
              child: const Icon(BootstrapIcons.plus,
                  size: 14, color: Color(0xFF8D91A5)),
            ),
          ),
          const Spacer(),
          const _WindowControls(),
        ],
      ),
    );
  }
}

/// The drag region wrapper: a double-click maximizes, a drag moves — the
/// two gestures a native titlebar carries and a hidden one must re-provide.
class _DragArea extends StatelessWidget {
  final Widget child;

  const _DragArea({required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => windowManager.startDragging(),
      onDoubleTap: () async {
        if (await windowManager.isMaximized()) {
          windowManager.unmaximize();
        } else {
          windowManager.maximize();
        }
      },
      child: child,
    );
  }
}

/// One titlebar tab pill: 20px icon + label, gap 10, padding 6/10, radius 10,
/// weight 450 (Q4e). Hover brightens the pill on --dark-grey-4.
class _TitlePill extends StatefulWidget {
  final Widget icon;
  final String label;
  final Widget? trailing;

  const _TitlePill({
    required this.icon,
    required this.label,
    this.trailing,
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
        child: _DragArea(
          child: AnimatedContainer(
            duration: TermiusMotion.micro,
            curve: TermiusMotion.easeOut,
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color:
                  _hovering ? theme.colorScheme.secondary : Colors.transparent,
              borderRadius: BorderRadius.circular(TermiusRadius.field),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                widget.icon,
                const SizedBox(width: 10),
                Text(widget.label,
                    style: theme.typography.normal
                        .copyWith(fontSize: 13, color: fg)),
                if (widget.trailing != null) ...[
                  const SizedBox(width: 8),
                  widget.trailing!,
                ],
              ],
            ),
          ),
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
          height: 51,
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