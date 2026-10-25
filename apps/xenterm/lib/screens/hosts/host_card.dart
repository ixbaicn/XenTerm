/// One host card — the original shows the real OS logo in a colored rounded
/// square, the name over "ssh, user, tag", and an edit pencil on hover.
/// Card: 60px tall, radius 15, --dark-grey-3 fill, no border.
library;

import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:simple_icons/simple_icons.dart';

import '../../data/hosts.dart';
import '../../theme/termius_theme.dart';

/// The OS chip: one neutral fill across distros (monochrome theme), with the
/// actual brand glyph (Simple Icons) as the only differentiator.
class OsChip {
  final Color fill;
  final IconData glyph;

  const OsChip(this.fill, this.glyph);
}

OsChip osChipFor(HostOs os) => switch (os) {
      HostOs.debian => const OsChip(Color(0xFF3A3A3A), SimpleIcons.debian),
      HostOs.ubuntu => const OsChip(Color(0xFF3A3A3A), SimpleIcons.ubuntu),
      HostOs.arch => const OsChip(Color(0xFF3A3A3A), SimpleIcons.archlinux),
      HostOs.linux => const OsChip(Color(0xFF3A3A3A), SimpleIcons.linux),
      HostOs.windows =>
        const OsChip(Color(0xFF3A3A3A), LucideIcons.appWindow),
      HostOs.apple => const OsChip(Color(0xFF3A3A3A), SimpleIcons.apple),
      HostOs.android => const OsChip(Color(0xFF3A3A3A), SimpleIcons.android),
    };

class HostCard extends StatefulWidget {
  final Host host;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final bool grid;

  const HostCard.grid({
    super.key,
    required this.host,
    required this.selected,
    required this.onTap,
    required this.onEdit,
  }) : grid = true;

  const HostCard.row({
    super.key,
    required this.host,
    required this.selected,
    required this.onTap,
    required this.onEdit,
  }) : grid = false;

  @override
  State<HostCard> createState() => _HostCardState();
}

class _HostCardState extends State<HostCard> {
  bool _hovering = false;

  static const _cardFill = Color(0xFF1B1B1B); // --dark-grey-3 / --card-a
  static const _cardHover = Color(0xFF2E2E2E); // one step up
  static const _subtitle = Color(0xFFA6A6A6); // --dark-grey-7

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
                    key: ValueKey('edit-${host.id}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onEdit,
                    child: Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3A3A3A),
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
