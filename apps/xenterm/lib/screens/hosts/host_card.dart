/// One host card — the original shows a colored OS logo chip (Debian swirl
/// pink / Ubuntu orange alternate), name over "ssh, user, tag" detail, and
/// an edit-pencil button that appears on hover. No visible border: the
/// lighter fill separates the card from the darker page.
library;

import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../data/hosts.dart';
import '../../theme/termius_theme.dart';

/// The OS chip palette cycles per card, echoing the original's colored OS
/// logos (Debian pink-red, Ubuntu orange, Arch blue…).
class OsChip {
  final Color fill;
  final IconData icon;

  const OsChip(this.fill, this.icon);
}

const _osChips = <OsChip>[
  OsChip(Color(0xFFD70A53), BootstrapIcons.lightningChargeFill), // Debian pink
  OsChip(Color(0xFFE95420), BootstrapIcons.circleFill), // Ubuntu orange
  OsChip(Color(0xFF1793D1), BootstrapIcons.diamondHalf), // Arch blue
];

OsChip osChipFor(int index) => _osChips[index % _osChips.length];

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
    final chip = osChipFor(host.id.hashCode.abs());
    // Selection rings the card with the accent; hover lightens the fill one
    // step and reveals the edit pencil.
    final border = selected
        ? Border.all(color: theme.colorScheme.primary, width: 1.5)
        : Border.all(color: Colors.transparent);
    final fill = _hovering
        ? theme.colorScheme.secondary.withValues(alpha: 0.9)
        : theme.colorScheme.secondary;

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
          height: 76,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(10),
            border: border,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: chip.fill,
                  shape: BoxShape.circle,
                ),
                child: Icon(chip.icon, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      host.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.medium.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ssh, ${host.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.normal.copyWith(
                          fontSize: 13, color: theme.colorScheme.mutedForeground),
                    ),
                  ],
                ),
              ),
              // The edit pencil: hidden until hover (200ms fade), the
              // original's per-card quick action.
              AnimatedOpacity(
                duration: TermiusMotion.micro,
                curve: TermiusMotion.easeOut,
                opacity: _hovering ? 1 : 0,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {},
                    child: Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.card,
                        borderRadius: BorderRadius.circular(TermiusRadius.card),
                      ),
                      child: const Icon(BootstrapIcons.pencil,
                          size: 14, color: Colors.white),
                    ),
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
