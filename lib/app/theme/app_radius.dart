import 'package:flutter/widgets.dart';

/// Corner radii.
abstract final class AppRadius {
  static const double sm = 8;
  static const double cover = 12;
  static const double card = 16;
  static const double coverLarge = 16;
  static const double sheet = 24;
  static const double pill = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius coverAll = BorderRadius.all(Radius.circular(cover));
  static const BorderRadius cardAll = BorderRadius.all(Radius.circular(card));
  static const BorderRadius coverLargeAll = BorderRadius.all(
    Radius.circular(coverLarge),
  );
  static const BorderRadius sheetTop = BorderRadius.vertical(
    top: Radius.circular(sheet),
  );
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
}
