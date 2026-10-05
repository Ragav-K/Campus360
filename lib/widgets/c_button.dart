import 'package:flutter/material.dart';

import '../core/theme/app_spacing.dart';

/// Primary action button.
///
/// Owns the "don't let the user submit twice" rule from §33: while [loading]
/// is true the button is disabled *and* shows a spinner, so no screen has to
/// remember to guard its own submit handler.
class CButton extends StatelessWidget {
  const CButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.variant = CButtonVariant.filled,
    this.expand = true,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final CButtonVariant variant;
  final bool expand;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null && !loading;

    final child = loading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: variant == CButtonVariant.filled ? scheme.onPrimary : scheme.primary,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[Icon(icon, size: 19), Gap.w8],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );

    final button = switch (variant) {
      CButtonVariant.filled => FilledButton(
          onPressed: enabled ? onPressed : null,
          style: danger ? FilledButton.styleFrom(backgroundColor: scheme.error) : null,
          child: child,
        ),
      CButtonVariant.outlined => OutlinedButton(
          onPressed: enabled ? onPressed : null,
          style: danger ? OutlinedButton.styleFrom(foregroundColor: scheme.error) : null,
          child: child,
        ),
      CButtonVariant.text => TextButton(
          onPressed: enabled ? onPressed : null,
          style: danger ? TextButton.styleFrom(foregroundColor: scheme.error) : null,
          child: child,
        ),
    };

    // Announce busy state to screen readers, not just visually.
    final semantic = Semantics(
      button: true,
      enabled: enabled,
      label: loading ? '$label, in progress' : label,
      child: button,
    );

    return expand ? SizedBox(width: double.infinity, child: semantic) : semantic;
  }
}

enum CButtonVariant { filled, outlined, text }
