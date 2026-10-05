import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';

/// The quick-action row from §36. Every tile navigates somewhere real —
/// tiles for modules that don't exist yet are simply not shown.
class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionTile(
            icon: Icons.map_outlined,
            label: 'Find location',
            onTap: () => context.go(Routes.map),
          ),
        ),
        Gap.w12,
        Expanded(
          child: _ActionTile(
            icon: Icons.search_rounded,
            label: 'Lost & Found',
            onTap: () => context.go(Routes.lostFound),
          ),
        ),
        Gap.w12,
        Expanded(
          child: _ActionTile(
            icon: Icons.print_outlined,
            label: 'New print order',
            onTap: () => context.go(Routes.print),
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: Radii.md,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 92,
          decoration: BoxDecoration(
            borderRadius: Radii.md,
            border: Border.all(color: theme.colorScheme.outline),
          ),
          padding: const EdgeInsets.all(Gap.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: theme.colorScheme.primary, size: 24),
              Gap.h8,
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Greeting line: "Good morning 👋 / Ragav".
class HomeGreeting extends StatelessWidget {
  const HomeGreeting({super.key, required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = Fmt.firstName(name);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${Fmt.greeting()} 👋', style: theme.textTheme.bodySmall),
        if (first.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(first, style: theme.textTheme.headlineSmall),
        ],
      ],
    );
  }
}
