import 'package:flutter/painting.dart';

/// NotaKit radius tokens — source of truth: docs/DESAIN.md §7.
abstract final class AppRadius {
  static const double smallValue = 8;
  static const double mediumValue = 12;
  static const double largeValue = 16;
  static const double extraValue = 20;
  static const double bottomSheetTopValue = 24;

  static final BorderRadius small = BorderRadius.circular(smallValue);
  static final BorderRadius medium = BorderRadius.circular(mediumValue);
  static final BorderRadius large = BorderRadius.circular(largeValue);
  static final BorderRadius extra = BorderRadius.circular(extraValue);
  static final BorderRadius bottomSheetTop = BorderRadius.vertical(
    top: Radius.circular(bottomSheetTopValue),
  );
}
