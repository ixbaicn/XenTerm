/// Shared toolbar widgets — the split [icon Label | ▾] button, the ghost
/// icon+label action, and the square icon toggle — one implementation for
/// every screen's toolbar row (hosts, keychain, logs, port forwarding…).
library;

import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../theme/termius_theme.dart';

/// [+ Label | ▾] — one rounded container, hairline between the halves.
class SplitButton extends StatefulWidget {
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
  State<SplitButton> createState() => _SplitButtonState();
}

class _SplitButtonState extends State<SplitButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: TermiusMotion.micro,
        curve: TermiusMotion.easeOut,
        height: 36,
        decoration: BoxDecoration(
          color: _hovering
              ? theme.colorScheme.secondary
              : theme.colorScheme.secondary.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(TermiusRadius.card),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onPressed,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon,
                        size: 14, color: theme.colorScheme.foreground),
                    const SizedBox(width: 8),
                    Text(widget.label,
                        style: theme.typography.normal.copyWith(
                            fontSize: 14,
                            color: theme.colorScheme.foreground)),
                  ],
                ),
              ),
            ),
            Container(width: 1, height: 20, color: theme.colorScheme.border),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onDropdown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 9),
                child: Icon(BootstrapIcons.caretDownFill,
                    size: 11, color: theme.colorScheme.foreground),
              ),
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
