import 'package:flutter/material.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_spacing.dart';
import 'brand_mark.dart';

/// Shared chrome for the four auth screens: centred, max-width, scrollable so
/// the keyboard never covers the submit button, with a slot for an inline
/// error banner (auth errors belong next to the form, not in a snackbar).
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.failure,
    this.showBack = true,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final AppFailure? failure;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: showBack ? AppBar(backgroundColor: Colors.transparent) : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.lg, Gap.xl, Gap.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!showBack) ...[
                    const Align(alignment: Alignment.centerLeft, child: BrandMark()),
                    Gap.h24,
                  ],
                  Text(title, style: theme.textTheme.headlineSmall),
                  Gap.h8,
                  Text(subtitle, style: theme.textTheme.bodySmall),
                  Gap.h24,
                  if (failure != null) ...[
                    _ErrorBanner(failure: failure!),
                    Gap.h16,
                  ],
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.failure});
  final AppFailure failure;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(Gap.md),
        decoration: BoxDecoration(
          color: scheme.error.withValues(alpha: 0.10),
          borderRadius: Radii.md,
          border: Border.all(color: scheme.error.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded, size: 20, color: scheme.error),
            Gap.w12,
            Expanded(
              child: Text(
                failure.message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
