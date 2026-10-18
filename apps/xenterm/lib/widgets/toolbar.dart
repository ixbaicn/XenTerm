/// Shared toolbar widgets — the split [icon Label | ▾] button, the ghost
/// icon+label action, and the square icon toggle — one implementation for
/// every screen's toolbar row (hosts, keychain, logs, port forwarding…).
library;

import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../theme/termius_theme.dart';

/// [+ Label | ▾] — the original is TWO segments 2px apart (source:
/// `toolbarButtonWithMenu { display:flex; gap:2px }`, main radius 8/2/2/8,
/// menu button square, radius 2/8/8/2). The chevron rotates 180° while open.
/// Its dropdown carries New Group / Import / the cloud integrations, the
/// integrations tagged with the upgrade badge.
class SplitMenuEntry {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const SplitMenuEntry({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

class SplitButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  /// Real menu entries. A null/empty list hides the chevron entirely instead
  /// of showing a menu whose items do nothing.
  final List<SplitMenuEntry>? menuItems;

  const SplitButton({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
    this.menuItems,
  });

  @override
  State<SplitButton> createState() => _SplitButtonState();
}

class _SplitButtonState extends State<SplitButton> {
  final OverlayPortalController _menu = OverlayPortalController();
  final LayerLink _link = LayerLink();

  void _toggleMenu() {
    if (_menu.isShowing) {
      _menu.hide();
    } else {
      _menu.show();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const outer = Radius.circular(TermiusRadius.card); // 8
    const inner = Radius.circular(2);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SplitSegment(
          onTap: widget.onPressed,
          radius: const BorderRadius.only(
            topLeft: outer,
            bottomLeft: outer,
            topRight: inner,
            bottomRight: inner,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 14, color: theme.colorScheme.foreground),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: theme.typography.medium.copyWith(
                  fontSize: 14,
                  color: theme.colorScheme.foreground,
                ),
              ),
            ],
          ),
        ),
        if (widget.menuItems?.isNotEmpty ?? false) ...[
          const SizedBox(width: 2),
          CompositedTransformTarget(
            link: _link,
            child: _SplitSegment(
              onTap: _toggleMenu,
              radius: const BorderRadius.only(
                topLeft: inner,
                bottomLeft: inner,
                topRight: outer,
                bottomRight: outer,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: AnimatedRotation(
                turns: _menu.isShowing ? 0.5 : 0,
                duration: TermiusMotion.micro,
                curve: TermiusMotion.easeOut,
                child: Icon(
                  LucideIcons.chevronDown,
                  size: 14,
                  color: theme.colorScheme.foreground,
                ),
              ),
            ),
          ),
          OverlayPortal(controller: _menu, overlayChildBuilder: _overlay),
        ],
      ],
    );
  }

  Widget _overlay(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _menu.hide,
            child: const ColoredBox(color: Colors.transparent),
          ),
        ),
        CompositedTransformFollower(
          link: _link,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 8), // source: menu marginTop 8px
          showWhenUnlinked: false,
          child: Align(
            alignment: Alignment.topLeft,
            child: Container(
              width: 300,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFF282B3D), // --card-c
                borderRadius: BorderRadius.circular(TermiusRadius.field),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final item in widget.menuItems!)
                    _MenuEntry(
                      icon: item.icon,
                      label: item.label,
                      onTap: () {
                        _menu.hide();
                        item.onTap();
                      },
                      theme: theme,
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One split-button segment: its own rounded rect, hover one step lighter.
class _SplitSegment extends StatefulWidget {
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final BorderRadius radius;
  final Widget child;

  const _SplitSegment({
    required this.onTap,
    required this.padding,
    required this.radius,
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
          height: 36,
          padding: widget.padding,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _hovering
                ? const Color(0xFF3E4257)
                : const Color(0xFF32364A),
            borderRadius: widget.radius,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// One dropdown row: 16px icon, 14px label.
class _MenuEntry extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ThemeData theme;

  const _MenuEntry({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.theme,
  });

  @override
  State<_MenuEntry> createState() => _MenuEntryState();
}

class _MenuEntryState extends State<_MenuEntry> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
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
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: _hovering ? const Color(0xFF3E4257) : Colors.transparent,
            borderRadius: BorderRadius.circular(TermiusRadius.card),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 16, color: const Color(0xFF8D91A5)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.label,
                  style: theme.typography.medium.copyWith(
                    fontSize: 14,
                    color: theme.colorScheme.foreground,
                  ),
                ),
              ),
            ],
          ),
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
              Text(
                widget.label,
                style: theme.typography.normal.copyWith(
                  fontSize: 14,
                  color: theme.colorScheme.foreground,
                ),
              ),
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
          child: Icon(
            widget.icon,
            size: 15,
            color: theme.colorScheme.foreground,
          ),
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
      child: Text(
        text,
        style: theme.typography.bold.copyWith(
          fontSize: 18,
          color: theme.colorScheme.foreground,
        ),
      ),
    );
  }
}
