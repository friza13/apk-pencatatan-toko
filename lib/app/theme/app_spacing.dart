/// NotaKit spacing tokens (4pt base) — source of truth: docs/DESAIN.md §6.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;
  static const double massive = 48;

  /// Default horizontal page padding on phones.
  static const double pagePadding = lg;

  /// Elevated page padding for tablets (DESAIN.md §30).
  static const double tabletPagePadding = xxl;

  /// Section spacing.
  static const double section = xxl;
}
