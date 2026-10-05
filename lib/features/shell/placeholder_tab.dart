import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../widgets/state_views.dart';
import '../auth/providers/auth_providers.dart';

/// Honest placeholder for tabs not yet implemented (§40: no dead buttons, no
/// features pretending to work). Replaced module by module in Phases 2–4.
class PlaceholderTab extends ConsumerWidget {
  const PlaceholderTab({super.key, required this.title, required this.icon, required this.phase});

  final String title;
  final IconData icon;
  final String phase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
          Gap.w8,
        ],
      ),
      body: Column(
        children: [
          if (user != null)
            Padding(
              padding: kPagePadding,
              child: Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text(user.initials)),
                  title: Text(user.displayName.isEmpty ? user.email : user.displayName),
                  subtitle: Text('${user.role.label} · ${user.emailVerified ? 'Verified' : 'Email not verified'}'),
                ),
              ),
            ),
          Expanded(
            child: EmptyState(
              icon: icon,
              title: '$title is not built yet',
              message: 'This module arrives in $phase. Nothing here is a mock — '
                  'the screen will be replaced with the real feature.',
            ),
          ),
        ],
      ),
    );
  }
}
