/// Shared toolbar widgets — the split [icon Label | ▾] button, the ghost
/// icon+label action, and the square icon toggle — one implementation for
/// every screen's toolbar row (hosts, keychain, logs, port forwarding…).
library;

import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../theme/termius_theme.dart';

/// [+ Label | ▾] — the original is ONE pill (--dark-grey-4) split by a
/// hairline, each half highlighting on its own hover.
class SplitButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final VoidCallback? onDropdown;

  const SplitButton({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
    this.onDropdown,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(TermiusRadius.field),
      child: Container(
        height: 36,
        color: const Color(0xFF32364A), // --dark-grey-4
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SplitSegment(
              onTap: onPressed,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: theme.colorScheme.foreground),
                  const SizedBox(width: 8),
                  Text(label,
                      style: theme.typography.medium.copyWith(
                          fontSize: 14,
                          color: theme.colorScheme.foreground)),
                ],
              ),
            ),
            Container(
              width: 1,
              height: 20,
              color: const Color(0xFF282B3D), // hairline on the pill
            ),
            _SplitSegment(
              onTap: onDropdown,
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: Icon(BootstrapIcons.caretDownFill,
                  size: 11, color: theme.colorScheme.foreground),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ghost toolbar action: icon + label, hover chip.
class GhostAction extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const GhostAction({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
  });

  @override
  State<GhostAction> createState() => _GhostActionState();
}

class _GhostActionState extends State<GhostAction> {
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
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: _hovering ? theme.colorScheme.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(TermiusRadius.card),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 15, color: theme.colorScheme.foreground),
              const SizedBox(width: 8),
              Text(widget.label,
                  style: theme.typography.normal.copyWith(
                      fontSize: 14, color: theme.colorScheme.foreground)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Square icon toggle (grid/tag/search/keyboard…).
class IconToggleButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const IconToggleButton({super.key, required this.icon, this.onPressed});

  @override
  State<IconToggleButton> createState() => _IconToggleButtonState();
}

class _IconToggleButtonState extends State<IconToggleButton> {
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
          height: 32,
          width: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _hovering ? theme.colorScheme.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(TermiusRadius.card),
          ),
          child: Icon(widget.icon,
              size: 15, color: theme.colorScheme.foreground),
        ),
      ),
    );
  }
}

/// The bold section title over a screen's content ("Hosts", "Keys"…).
class SectionTitle extends StatelessWidget {
  final String text;

  const SectionTitle({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 0, 12),
      child: Text(text,
          style: theme.typography.bold.copyWith(
              fontSize: 18, color: theme.colorScheme.foreground)),
    );
  }
}


/// One half of the split pill: independent hover, same fill as the parent
/// container until hovered.
class _SplitSegment extends StatefulWidget {
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Widget child;

  const _SplitSegment({
    required this.onTap,
    required this.padding,
    required this.child,
  });

  @override
  State<_SplitSegment> createState() => _SplitSegmentState();
}

class _SplitSegmentState extends State<_SplitSegment> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: TermiusMotion.micro,
          curve: TermiusMotion.easeOut,
          color: _hovering ? const Color(0xFF3E4257) : Colors.transparent,
          padding: widget.padding,
          alignment: Alignment.center,
          child: widget.child,
        ),
      ),
    );
  }
}
