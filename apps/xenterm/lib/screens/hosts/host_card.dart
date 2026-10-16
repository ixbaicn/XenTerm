/// One host, as the hosts screen shows it.
///
/// Values are Termius's own, extracted verbatim from its bundles:
/// grid card = width 430, padding 10/15, radius 15 (--corner-radius-large),
/// bg --card-a (dark-grey-3), shadow 0 1px 1px rgba(0,0,0,.25), no border;
/// list row = EntityItem: bg dark-grey-4, radius 14, padding 10, same shadow;
/// icon chip = 36x36, radius 8 (--corner-radius-small-medium), svg ≤20px.
library;

import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../data/hosts.dart';
import '../../theme/termius_theme.dart';

class HostCard extends StatefulWidget {
  final Host host;
  final bool selected;
  final VoidCallback onTap;
  final bool grid;

  const HostCard.grid({
    super.key,
    required this.host,
    required this.selected,
    required this.onTap,
  }) : grid = true;

  const HostCard.row({
    super.key,
    required this.host,
    required this.selected,
    required this.onTap,
  }) : grid = false;

  @override
  State<HostCard> createState() => _HostCardState();
}

class _HostCardState extends State<HostCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final host = widget.host;
    final selected = widget.selected;
    final grid = widget.grid;
    final onTap = widget.onTap;
    // Selection: Termius rings the card with the accent (the details panel's
    // open state); idle cards carry no border — the shadow separates them.
    final border = selected
        ? Border.all(color: theme.colorScheme.primary, width: 1.5)
        : Border.all(color: Colors.transparent);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: TermiusMotion.micro,
          curve: TermiusMotion.easeOut,
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            // grid card: --card-a (dark-grey-3); list row: dark-grey-4.
            // Hover brightens one step (--list-hover, dark-grey-5), matching
            // the original's entity hover.
            color: _hovering
                ? const Color(0xFF3E4257)
                : (grid
                    ? theme.colorScheme.card
                    : theme.colorScheme.secondary),
            borderRadius:
                BorderRadius.circular(grid ? TermiusRadius.cardLarge : 14),
            border: border,
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000), // rgba(0,0,0,.25)
                offset: Offset(0, 1),
                blurRadius: 1,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment(-1, -1), // 135deg
                    end: Alignment(1, 1),
                    colors: [
                      Color(0x26415E71), // dark-grey-4-a15
                      Color(0x26FFFFFF), // white-a15
                    ],
                  ),
                  borderRadius: BorderRadius.circular(TermiusRadius.card),
                ),
                child: Icon(
                  BootstrapIcons.hddRack,
                  size: 20,
                  color: theme.colorScheme.secondaryForeground,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      host.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.medium.copyWith(fontSize: 14),
                    ),
                    Text(
                      host.detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.normal.copyWith(
                          fontSize: 12, color: theme.colorScheme.mutedForeground),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
