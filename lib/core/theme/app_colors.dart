import 'package:flutter/material.dart';

/// Campus360 palette. Deep indigo primary, cyan accent, neutral surfaces.
/// Status colours are semantic and shared by Pulse, Lost & Found and Printout so
/// that "green means good" is true everywhere in the app.
abstract final class AppColors {
  // Brand
  static const primary = Color(0xFF2B3A8F);
  static const primaryDark = Color(0xFF1B255C);
  static const primaryLight = Color(0xFF5B6ACF);
  static const accent = Color(0xFF14B8C4);
  static const accentLight = Color(0xFF7FDDE4);

  // Light surfaces
  static const bgLight = Color(0xFFF5F6FA);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceAltLight = Color(0xFFEDEFF6);
  static const borderLight = Color(0xFFDFE2EC);
  static const textLight = Color(0xFF14172B);
  static const textMutedLight = Color(0xFF676C85);

  // Dark surfaces
  static const bgDark = Color(0xFF101223);
  static const surfaceDark = Color(0xFF1A1D33);
  static const surfaceAltDark = Color(0xFF23273F);
  static const borderDark = Color(0xFF32374F);
  static const textDark = Color(0xFFF2F3F8);
  static const textMutedDark = Color(0xFF9AA0BC);

  // Semantic status (§5, §7)
  static const success = Color(0xFF12A150); // available / completed
  static const warning = Color(0xFFD98A04); // moderate / pending
  static const danger = Color(0xFFD32F3C); // crowded / problem
  static const info = Color(0xFF2563EB); // information / in progress
  static const neutral = Color(0xFF6B7280); // closed / cancelled

  // Tinted backgrounds for status chips, resolved per brightness.
  static Color tint(Color c, Brightness b) =>
      b == Brightness.light ? Color.alphaBlend(c.withValues(alpha: 0.12), surfaceLight) : Color.alphaBlend(c.withValues(alpha: 0.22), surfaceDark);
}
