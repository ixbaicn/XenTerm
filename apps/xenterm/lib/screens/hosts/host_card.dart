/// One host, as the hosts screen shows it: the entity card (grid) or the
/// full-width row (list), per design-tokens.md §6.
library;

import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../data/hosts.dart';
import '../../theme/termius_theme.dart';

class HostCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Termius's entity card: surface-high fill, the 36px rounded icon chip on
    // dark-grey-4, name over user@host, group pill on the right, blue ring on
    // selection. Hover names the border; the fill animates with the MUI
    // micro cadence (200ms easeOut).
    final border = selected
        ? Border.all(color: theme.colorScheme.primary, width: 1.5)
        : Border.all(color: theme.colorScheme.border);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: TermiusMotion.micro,
          curve: TermiusMotion.easeOut,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.card,
            borderRadius: BorderRadius.circular(TermiusRadius.card),
            border: border,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary,
                  borderRadius: BorderRadius.circular(TermiusRadius.card),
                ),
                child: Icon(
                  BootstrapIcons.hddRack,
                  size: 16,
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
                    const SizedBox(height: 2),
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
              if (host.group.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  constraints: const BoxConstraints(maxWidth: 120),
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(TermiusRadius.pill),
                    border: Border.all(color: theme.colorScheme.border),
                  ),
                  child: Text(
                    host.group,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.normal.copyWith(
                        fontSize: 11, color: theme.colorScheme.mutedForeground),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
