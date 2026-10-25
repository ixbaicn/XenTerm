/// Shared building blocks for the host drawers.
///
/// The SSH editor and the serial editor render the same drawer surface; before
/// this file they had drifted apart (uppercase micro labels vs 15px section
/// titles, different card paddings), which read as two different products.
/// Both now compose these widgets so the typography, colours and spacing stay
/// identical.
library;

import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../theme/termius_field.dart';
import '../../theme/termius_theme.dart';

const hostCardSurface = Color(0xFF1B1B1B); // --dark-grey-3 / --card-a
const hostDivider = Color(0xFF3A3A3A); // --dark-grey-5
const hostTextDisabled = Color(0xFF6E6E6E); // --dark-grey-6
const hostTitleGrey = Color(0xFFA6A6A6); // --dark-grey-7
const hostHeaderBorder = Color(0xFF2E2E2E); // --dark-grey-4

/// One surface card with evenly spaced rows.
class HostFormCard extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  const HostFormCard({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(20, 15, 20, 20),
  });

  @override
  Widget build(BuildContext context) {
    final spaced = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) spaced.add(const SizedBox(height: 10));
      spaced.add(children[i]);
    }
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: hostCardSurface,
        borderRadius: BorderRadius.circular(TermiusRadius.field),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: spaced,
      ),
    );
  }
}

/// A 15px semibold card section title.
class HostSectionTitle extends StatelessWidget {
  final String text;

  const HostSectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.typography.medium.copyWith(
        fontSize: 15,
        color: theme.colorScheme.foreground,
      ),
    );
  }
}

/// The one drawer input: 36px TermiusField with an optional leading icon.
class HostPanelField extends StatelessWidget {
  final String placeholder;
  final TextEditingController controller;
  final IconData? leading;
  final double height;
  final bool obscure;

  const HostPanelField({
    super.key,
    required this.placeholder,
    required this.controller,
    this.leading,
    this.height = 36,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) {
    return TermiusField(
      placeholder: placeholder,
      controller: controller,
      height: height,
      obscure: obscure,
      leading: leading == null
          ? null
          : Icon(leading, size: 14, color: hostTextDisabled),
    );
  }
}

/// The drawer title bar: 56px, --dark-grey-3 surface, --dark-grey-4 border,
/// 16px/600 title with optional leading glyph and trailing actions.
class HostDrawerHeader extends StatelessWidget {
  final String title;
  final IconData? leading;
  final List<Widget> actions;

  const HostDrawerHeader({
    super.key,
    required this.title,
    this.leading,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 56,
      padding: const EdgeInsets.only(left: 15, right: 10),
      decoration: const BoxDecoration(
        color: hostCardSurface,
        border: Border(bottom: BorderSide(color: hostHeaderBorder)),
      ),
      child: Row(
        children: [
          if (leading != null) ...[
            Padding(
              padding: const EdgeInsets.only(left: 5),
              child: Icon(leading, size: 16, color: hostTitleGrey),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: leading == null ? 5 : 0),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.semiBold.copyWith(
                  fontSize: 16,
                  color: hostTitleGrey,
                ),
              ),
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}
