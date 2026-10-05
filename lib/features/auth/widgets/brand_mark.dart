import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// The Campus360 mark: a rounded square with a radar/pulse glyph, echoing the
/// Pulse module that anchors the product.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 56, this.onPrimary = false});

  final double size;
  final bool onPrimary;

  @override
  Widget build(BuildContext context) {
    final bg = onPrimary ? Colors.white.withValues(alpha: 0.16) : AppColors.primary;
    final fg = onPrimary ? Colors.white : Colors.white;

    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: onPrimary ? Border.all(color: Colors.white24) : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.sensors_rounded, size: size * 0.5, color: fg),
          Positioned(
            right: size * 0.18,
            bottom: size * 0.18,
            child: Container(
              height: size * 0.14,
              width: size * 0.14,
              decoration: const BoxDecoration(color: AppColors.accentLight, shape: BoxShape.circle),
            ),
          ),
        ],
      ),
    );
  }
}
