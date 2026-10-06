import 'package:campus360/core/theme/app_colors.dart';
import 'package:campus360/core/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('chip label contrast', () {
    test('light mode gives unselected and selected chips visible text', () {
      final chipTheme = AppTheme.light().chipTheme;

      expect(chipTheme.labelStyle?.color, AppColors.textLight);
      expect(chipTheme.secondaryLabelStyle?.color, AppColors.surfaceLight);
    });

    test('dark mode preserves visible chip text', () {
      final chipTheme = AppTheme.dark().chipTheme;

      expect(chipTheme.labelStyle?.color, AppColors.textDark);
      expect(chipTheme.secondaryLabelStyle?.color, AppColors.surfaceLight);
    });
  });
}
