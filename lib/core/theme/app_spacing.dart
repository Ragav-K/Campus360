import 'package:flutter/widgets.dart';

/// 4pt spacing scale. Use these rather than magic numbers so density stays
/// consistent across modules.
abstract final class Gap {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  static const h4 = SizedBox(height: xs);
  static const h8 = SizedBox(height: sm);
  static const h12 = SizedBox(height: md);
  static const h16 = SizedBox(height: lg);
  static const h24 = SizedBox(height: xl);
  static const h32 = SizedBox(height: xxl);

  static const w4 = SizedBox(width: xs);
  static const w8 = SizedBox(width: sm);
  static const w12 = SizedBox(width: md);
  static const w16 = SizedBox(width: lg);
}

abstract final class Radii {
  static const sm = BorderRadius.all(Radius.circular(8));
  static const md = BorderRadius.all(Radius.circular(14));
  static const lg = BorderRadius.all(Radius.circular(20));
  static const pill = BorderRadius.all(Radius.circular(999));
}

/// Minimum interactive size — accessibility requirement from §5.
const double kMinTouchTarget = 48.0;

/// Standard horizontal page padding.
const EdgeInsets kPagePadding = EdgeInsets.symmetric(horizontal: Gap.lg);
