import 'package:flutter/material.dart';

import '../core/errors/app_failure.dart';
import '../core/theme/app_spacing.dart';
import 'c_button.dart';

/// Polished empty state (§32). Never leave a blank screen.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: Gap.xl, vertical: compact ? Gap.xl : Gap.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(Gap.lg),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: compact ? 26 : 34, color: theme.colorScheme.primary),
            ),
            Gap.h16,
            Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            if (message != null) ...[
              Gap.h8,
              Text(message!, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
            ],
            if (actionLabel != null && onAction != null) ...[
              Gap.h16,
              CButton(label: actionLabel!, onPressed: onAction, variant: CButtonVariant.outlined, expand: false),
            ],
          ],
        ),
      ),
    );
  }
}

/// Error state (§31). Shows [AppFailure.message] — never a raw Firebase code.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({super.key, required this.failure, this.onRetry, this.compact = false});

  final AppFailure failure;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final icon = switch (failure.kind) {
      FailureKind.network => Icons.wifi_off_rounded,
      FailureKind.permission => Icons.lock_outline_rounded,
      FailureKind.notFound => Icons.search_off_rounded,
      FailureKind.upload => Icons.cloud_upload_outlined,
      FailureKind.fileTooLarge || FailureKind.unsupportedFile => Icons.insert_drive_file_outlined,
      _ => Icons.error_outline_rounded,
    };

    return EmptyState(
      icon: icon,
      title: switch (failure.kind) {
        FailureKind.network => "You're offline",
        FailureKind.permission => 'Not allowed',
        FailureKind.notFound => 'Not found',
        _ => 'Something went wrong',
      },
      message: failure.message,
      actionLabel: (failure.isRetryable && onRetry != null) ? 'Try again' : null,
      onAction: onRetry,
      compact: compact,
    );
  }
}

/// Shimmering skeleton block used by list placeholders (§33).
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.height = 16, this.width, this.borderRadius = Radii.sm});

  final double height;
  final double? width;
  final BorderRadius borderRadius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Container(
          height: widget.height,
          width: widget.width ?? double.infinity,
          decoration: BoxDecoration(
            color: Color.lerp(base, base.withValues(alpha: 0.45), _c.value),
            borderRadius: widget.borderRadius,
          ),
        ),
      ),
    );
  }
}

/// A card-shaped skeleton, matching the real card's silhouette so the swap to
/// loaded content doesn't jump.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.lines = 2});
  final int lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: Radii.md,
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Skeleton(height: 12, width: 70, borderRadius: Radii.pill),
            Gap.w8,
            Skeleton(height: 12, width: 44, borderRadius: Radii.pill),
          ]),
          Gap.h12,
          const Skeleton(height: 16, width: 190),
          for (var i = 0; i < lines; i++) ...[
            Gap.h8,
            Skeleton(height: 12, width: i.isEven ? double.infinity : 140),
          ],
        ],
      ),
    );
  }
}
