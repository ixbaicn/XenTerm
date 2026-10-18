/// One host card — the original shows the real OS logo in a colored rounded
/// square, the name over "ssh, user, tag", and an edit pencil on hover.
/// Card: 60px tall, radius 15, --dark-grey-3 fill, no border.
library;

import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:simple_icons/simple_icons.dart';

import '../../data/hosts.dart';
import '../../theme/termius_theme.dart';

/// The colored OS chip: brand fill + the actual brand glyph (Simple Icons),
/// matching the original's Debian swirl / Ubuntu roundel / Arch arrow.
class OsChip {
  final Color fill;
  final IconData glyph;

  const OsChip(this.fill, this.glyph);
}

OsChip osChipFor(HostOs os) => switch (os) {
      HostOs.debian => const OsChip(Color(0xFFCE0056), SimpleIcons.debian),
      HostOs.ubuntu => const OsChip(Color(0xFFE95420), SimpleIcons.ubuntu),
      HostOs.arch => const OsChip(Color(0xFF1793D1), SimpleIcons.archlinux),
      HostOs.linux => const OsChip(Color(0xFF3E4257), SimpleIcons.linux),
      HostOs.windows =>
        const OsChip(Color(0xFF2091F6), LucideIcons.appWindow),
      HostOs.apple => const OsChip(Color(0xFF5A5E73), SimpleIcons.apple),
      HostOs.android => const OsChip(Color(0xFF21B568), SimpleIcons.android),
    };

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

  static const _cardFill = Color(0xFF282B3D); // --dark-grey-3 / --card-a
  static const _cardHover = Color(0xFF32364A); // one step up
  static const _subtitle = Color(0xFF8D91A5); // --dark-grey-7

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final host = widget.host;
    final selected = widget.selected;
    final chip = osChipFor(host.os);
    final border = selected
        ? Border.all(color: theme.colorScheme.primary, width: 1.5)
        : Border.all(color: Colors.transparent);
    final fill = _hovering ? _cardHover : _cardFill;

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
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(TermiusRadius.cardLarge),
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
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(chip.glyph, size: 22, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      host.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.semiBold.copyWith(
                        fontSize: 16,
                        color: theme.colorScheme.foreground,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      host.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.normal.copyWith(
                        fontSize: 13,
                        color: _subtitle,
                      ),
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
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3E4257),
                        borderRadius: BorderRadius.circular(TermiusRadius.menu),
                      ),
                      child: const Icon(LucideIcons.pencil,
                          size: 13, color: Colors.white),
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
