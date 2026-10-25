/// XenTerm monochrome theme — a layered black-and-white palette.
///
/// The palette is a single neutral ramp from near-black surfaces to white
/// text, with white as the accent (primary buttons are white with black
/// text). The only non-neutral color left in the UI is destructive red, for
/// errors and destructive actions. The token record lives in
/// docs/termius/design-tokens.md (§ XenTerm 单色主题).
library;

import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The dark ramp: black-950 (lowest surface) → white (text / accent).
abstract final class Mono {
  static const Color black950 = Color(0xFF0A0A0A); // terminal, titlebar
  static const Color black900 = Color(0xFF111111); // window / page bg
  static const Color black850 = Color(0xFF161616); // sunken panels
  static const Color black800 = Color(0xFF1B1B1B); // cards, menus, popovers
  static const Color black750 = Color(0xFF1F1F1F); // hairline fills
  static const Color black700 = Color(0xFF262626); // elevated tiles
  static const Color black600 = Color(0xFF2E2E2E); // inputs, buttons
  static const Color black500 = Color(0xFF3A3A3A); // strong borders, chips
  static const Color grey400 = Color(0xFF6E6E6E); // disabled text
  static const Color grey300 = Color(0xFFA6A6A6); // secondary text
  static const Color grey200 = Color(0xFFD4D4D4); // strong text
  static const Color white = Color(0xFFFFFFFF); // primary text / accent

  /// Light-mode ladder: the same ramp inverted around paper white.
  static const Color paperBase = Color(0xFFFAFAFA);
  static const Color paperCard = Color(0xFFFFFFFF);
  static const Color paperText = Color(0xFF171717);
  static const Color paperGrey = Color(0xFF8A8A8A);
}

/// The destructive red is the only functional color kept: errors and
/// destructive actions must stay unmistakable in a monochrome UI.
abstract final class MonoDestructive {
  static const Color solid = Color(0xFFE5484D);
  static const Color tint = Color(0x33E5484D);
  static const Color light = Color(0xFFFF8A8D);
}

ColorScheme termiusDarkScheme() {
  const base = Mono.black900;
  const cards = Mono.black800;
  const forms = Mono.black600;
  const secondary = Mono.grey300;
  // White at low alpha plays the role the old hover/border tints played.
  final hover = Colors.white.withValues(alpha: 0.06);
  final border = Colors.white.withValues(alpha: 0.16);
  return ColorScheme(
    brightness: Brightness.dark,
    background: base,
    foreground: Mono.white,
    card: cards, // cards are one step LIGHTER than the page bg
    cardForeground: Mono.white,
    popover: cards,
    popoverForeground: Mono.white,
    primary: Mono.white, // accent = white; primary buttons: white on black
    primaryForeground: Mono.black950,
    secondary: forms,
    secondaryForeground: Mono.grey200,
    muted: hover,
    mutedForeground: secondary,
    accent: hover,
    accentForeground: Mono.white,
    destructive: MonoDestructive.solid,
    destructiveForeground: Mono.white,
    border: border,
    input: forms,
    ring: Mono.white, // focus ring: white
    chart1: Mono.white,
    chart2: Mono.grey300,
    chart3: Color(0xFF8C8C8C),
    chart4: Color(0xFF666666),
    chart5: Color(0xFF4D4D4D),
  );
}

/// The light scheme: the same ramp inverted around paper white.
ColorScheme termiusLightScheme() {
  const text = Mono.paperText;
  final border = text.withValues(alpha: 0.16);
  final hover = text.withValues(alpha: 0.06);
  return ColorScheme(
    brightness: Brightness.light,
    background: Mono.paperBase,
    foreground: text,
    card: Mono.paperCard,
    cardForeground: text,
    popover: Mono.paperCard,
    popoverForeground: text,
    primary: text, // accent = black; primary buttons: black on white
    primaryForeground: Mono.paperCard,
    secondary: Mono.paperCard,
    secondaryForeground: text,
    muted: hover,
    mutedForeground: Mono.paperGrey,
    accent: hover,
    accentForeground: text,
    destructive: MonoDestructive.solid,
    destructiveForeground: Colors.white,
    border: border,
    input: Mono.paperCard,
    ring: text,
    chart1: text,
    chart2: Color(0xFF555555),
    chart3: Color(0xFF777777),
    chart4: Color(0xFF999999),
    chart5: Color(0xFFBBBBBB),
  );
}

/// Radius slots from the original scale: the theme's multiplier is left at
/// 0.5 and these constants are used at the call sites, so a card says
/// `TermiusRadius.card` and the number is the spec's, not a multiplier's
/// byproduct.
class TermiusRadius {
  static const double menu = 6;
  static const double card = 8;
  static const double field = 10;
  static const double cardLarge = 15;
  static const double pill = 1000;
}

/// Layout metric constants (design-tokens.md §4).
abstract final class TermiusMetrics {
  /// The search+Connect row's height.
  static const double headerHeight = 56;

  /// The search field's inner height and its dark fill.
  static const double searchFieldHeight = 36;
  static const Color searchFieldFill = Mono.black500;

  /// HostsFiltersHeader: height 45, padding 4/12, gap 15.
  static const double toolbarHeight = 45;

  /// The hosts grid card's on-disk width (it may shrink in a narrower pane).
  static const double gridCardWidth = 430;
}

/// Brightness-aware strip colors: the titlebar/tabs bar sits one step off
/// the content surface in both modes.
Color termiusTitleBarColor(Brightness brightness) =>
    brightness == Brightness.dark
        ? Mono.black950
        : const Color(0xFFF2F2F2);

Color termiusTitleBarBorderColor(Brightness brightness) =>
    brightness == Brightness.dark
        ? const Color(0xFF262626)
        : Mono.paperText.withValues(alpha: 0.12);

/// Duration/easing slots (MUI-derived, unchanged by the retheme).
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
