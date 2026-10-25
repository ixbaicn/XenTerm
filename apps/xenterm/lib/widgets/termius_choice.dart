/// A 36px filled select with an anchored dropdown, matching TermiusField.
library;

import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../theme/termius_theme.dart';

class TermiusChoice<T> extends StatefulWidget {
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;
  final double height;

  const TermiusChoice({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.height = 36,
  });

  @override
  State<TermiusChoice<T>> createState() => _TermiusChoiceState<T>();
}

class _TermiusChoiceState<T> extends State<TermiusChoice<T>> {
  final OverlayPortalController _menu = OverlayPortalController();
  final LayerLink _link = LayerLink();
  final GlobalKey _anchorKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = widget.options[widget.value] ?? '${widget.value}';
    return OverlayPortal(
      controller: _menu,
      overlayChildBuilder: _overlay,
      child: CompositedTransformTarget(
        link: _link,
        child: GestureDetector(
          onTap: () => _menu.isShowing ? _menu.hide() : _menu.show(),
          child: Container(
            key: _anchorKey,
            height: widget.height,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary,
              borderRadius: BorderRadius.circular(TermiusRadius.field),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: theme.colorScheme.foreground,
                    ),
                  ),
                ),
                Icon(
                  LucideIcons.chevronDown,
                  size: 14,
                  color: theme.colorScheme.mutedForeground,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _overlay(BuildContext context) {
    final theme = Theme.of(context);
    // Keep the list inside the window: open upward when the field sits near
    // the bottom (the serial drawer is the common case).
    final screen = MediaQuery.sizeOf(context);
    final box = _anchorKey.currentContext?.findRenderObject() as RenderBox?;
    var maxHeight = 240.0;
    if (box != null && box.hasSize) {
      final origin = box.localToGlobal(Offset.zero);
      final below = screen.height - (origin.dy + box.size.height + 6);
      maxHeight = (below - 10).clamp(100.0, 240.0);
    }
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
          offset: const Offset(0, 6),
          showWhenUnlinked: false,
          child: Align(
            alignment: Alignment.topLeft,
            child: Container(
              constraints: BoxConstraints(minWidth: 160, maxHeight: maxHeight),
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1B1B),
                borderRadius: BorderRadius.circular(TermiusRadius.field),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final entry in widget.options.entries)
                      GestureDetector(
                        onTap: () {
                          _menu.hide();
                          widget.onChanged(entry.key);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: entry.key == widget.value
                                ? theme.colorScheme.muted
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  entry.value,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: theme.colorScheme.foreground,
                                  ),
                                ),
                              ),
                              if (entry.key == widget.value)
                                Icon(
                                  LucideIcons.check,
                                  size: 14,
                                  color: theme.colorScheme.primary,
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
