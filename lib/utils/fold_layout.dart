import 'dart:math' as math;
import 'dart:ui' show DisplayFeatureType;

import 'package:flutter/material.dart';

/// Cover-screen (folded) vs inner-screen (unfolded / Continuous) foldables.
class FoldLayout {
  FoldLayout._();

  /// Outer/cover screens (Galaxy Z Fold cover is ~344 logical px).
  static const double foldedMaxWidth = 400;

  static double widthOf(BuildContext context) => MediaQuery.sizeOf(context).width;

  static bool isFoldedCover(BuildContext context) => widthOf(context) < foldedMaxWidth;

  /// Inner Fold / short phones (Z Fold 5 Continuous is ~829 logical px tall).
  static bool isShortViewport(BuildContext context) =>
      MediaQuery.sizeOf(context).height < 900;

  static bool isCompact(BuildContext context) =>
      isFoldedCover(context) || isShortViewport(context);

  static double pagePadding(BuildContext context) {
    final w = widthOf(context);
    final short = isShortViewport(context);
    if (w < 360) return short ? 8 : 10;
    if (w < foldedMaxWidth) return short ? 8 : 12;
    if (w < 720) return short ? 10 : 16;
    return 24;
  }

  /// Width of a vertical hinge/fold. Uses [DisplayFeature] when the OS reports it;
  /// otherwise a center gutter on tall inner-fold viewports (Chrome Continuous).
  static double verticalHingeGutter(BuildContext context) {
    for (final f in MediaQuery.displayFeaturesOf(context)) {
      final vertical = f.bounds.height >= f.bounds.width;
      if (vertical &&
          (f.type == DisplayFeatureType.hinge || f.type == DisplayFeatureType.fold)) {
        return math.max(f.bounds.width, 20);
      }
    }
    final size = MediaQuery.sizeOf(context);
    final tallInner = size.width >= 560 &&
        size.width < 900 &&
        size.height >= size.width * 0.95;
    return tallInner ? 28 : 0;
  }
}
