/// Termius design tokens, installed into shadcn_flutter's theme system.
///
/// Every color below is a verbatim value extracted from Termius 10.2.1's own
/// stylesheet — the reverse-engineering record lives in
/// docs/termius/design-tokens.md. The mapping onto shadcn_flutter's
/// [ColorScheme] slots is documented per line; when the Flutter frontend and
/// the spec disagree, the spec wins.
library;

import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Termius's dark palette. `--dark-grey-*` and the alpha tints built on
/// dark-grey-7 carry the surfaces; `--blue` is the accent.
ColorScheme termiusDarkScheme() {
  const d2 = Color(0xFF1D2033); // --surface-base
  const d3 = Color(0xFF282B3D); // --surface-high (cards, menus)
  const d4 = Color(0xFF32364A); // --button-regular / --main-form-bg
  const d7 = Color(0xFF8D91A5); // --text-secondary
  const blue = Color(0xFF2091F6); // --button-accent
  const greenMedium = Color(0xFF00CC74); // --input-border-focused
  // dark-grey-7 at 10% and 25%: --surface-hover-basic and --border-basic.
  final hover = d7.withValues(alpha: 0.10);
  final border = d7.withValues(alpha: 0.25);
  return ColorScheme(
    brightness: Brightness.dark,
    background: d2,
    foreground: Colors.white, // --text-primary
    card: d4, // grid cards are LIGHTER than the base bg (原版对比)
    cardForeground: Colors.white,
    popover: d3,
    popoverForeground: Colors.white,
    primary: blue,
    primaryForeground: Colors.white,
    secondary: d4,
    secondaryForeground: const Color(0xFFA4B3BA), // --light-grey-3
    muted: hover,
    mutedForeground: d7,
    accent: hover,
    accentForeground: Colors.white,
    destructive: const Color(0xFFF25E61), // --red
    destructiveForeground: Colors.white,
    border: border,
    input: d4,
    ring: greenMedium,
    chart1: blue,
    chart2: const Color(0xFF21B568), // --green
    chart3: const Color(0xFFF8AA4B), // --orange
    chart4: const Color(0xFF54D2D2), // --teal
    chart5: const Color(0xFFAF5FFF), // --purple
  );
}

/// Termius's light palette: the `--light-grey` ladder.
ColorScheme termiusLightScheme() {
  const l1 = Color(0xFF798C94); // --light-grey-1
  const l6 = Color(0xFFEDF1F2); // --surface-base
  const l7 = Color(0xFFF7F9FA); // --surface-high
  const d1 = Color(0xFF141729); // --text-primary (light mode)
  final border = l1.withValues(alpha: 0.25);
  return ColorScheme(
    brightness: Brightness.light,
    background: l6,
    foreground: d1,
    card: l7,
    cardForeground: d1,
    popover: l7,
    popoverForeground: d1,
    primary: const Color(0xFF2091F6),
    primaryForeground: Colors.white,
    secondary: Colors.white,
    secondaryForeground: d1,
    muted: l1.withValues(alpha: 0.10),
    mutedForeground: l1,
    accent: l1.withValues(alpha: 0.10),
    accentForeground: d1,
    destructive: const Color(0xFFF25E61),
    destructiveForeground: Colors.white,
    border: border,
    input: Colors.white,
    ring: const Color(0xFF00CC74),
    chart1: const Color(0xFF2091F6),
    chart2: const Color(0xFF21B568),
    chart3: const Color(0xFFF8AA4B),
    chart4: const Color(0xFF54D2D2),
    chart5: const Color(0xFFAF5FFF),
  );
}

/// Radius slots straight from the Termius scale (design-tokens.md §4): the
/// theme's multiplier is left at 0.5 and these constants are used at the call
/// sites, so a card says `TermiusRadius.card` and the number is the spec's,
/// not a multiplier's byproduct.
class TermiusRadius {
  static const double menu = 6; // --corner-radius-small-increased
  static const double card = 8; // --corner-radius-small-medium (icon chips)
  static const double field = 10; // --corner-radius-medium (inputs, tabs)
  static const double cardLarge = 15; // --corner-radius-large (host cards)
  static const double pill = 1000; // --corner-radius-full
}

/// Termius metric constants extracted verbatim from its bundles
/// (docs/termius/design-tokens.md §4 and the component style dumps).
abstract final class TermiusMetrics {
  /// --header-height: the search+Connect row's height.
  static const double headerHeight = 56;

  /// The search field's inner height and its dark fill (--dark-grey-5).
  static const double searchFieldHeight = 36;
  static const Color searchFieldFill = Color(0xFF3E4257);

  /// HostsFiltersHeader: height 45, padding 4/12, gap 15.
  static const double toolbarHeight = 45;

  /// The hosts grid card's on-disk width (it may shrink in a narrower pane).
  static const double gridCardWidth = 430;
}

/// Duration/easing slots from Termius's MUI theme (design-tokens.md §5).
abstract final class TermiusMotion {
  /// MUI `shorter`: micro-feedback (color fades, hover reveals).
  static const Duration micro = Duration(milliseconds: 200);

  /// MUI `standard`/Collapse-expand: panels, sections, rail.
  static const Duration panel = Duration(milliseconds: 300);

  /// MUI `leavingScreen`: the faster half of a collapse.
  static const Duration collapse = Duration(milliseconds: 200);

  /// MUI easeOut `cubic-bezier(0, 0, 0.2, 1)`.
  static const Curve easeOut = Cubic(0, 0, 0.2, 1);

  /// MUI easeInOut `cubic-bezier(0.4, 0, 0.2, 1)`.
  static const Curve easeInOut = Cubic(0.4, 0, 0.2, 1);
}
