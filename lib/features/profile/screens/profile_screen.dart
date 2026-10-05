import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app.dart';
import '../../../core/constants/routes.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/tile_cache.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/app_user.dart';
import '../../../widgets/c_button.dart';
import '../../../widgets/state_views.dart';
import '../../auth/providers/auth_providers.dart';
import '../../notifications/providers/notification_providers.dart';
import '../../campus_map/widgets/map_download_sheet.dart';
import '../../timetable/providers/timetable_providers.dart';
import '../../timetable/widgets/section_picker.dart';
import '../widgets/edit_name_sheet.dart';

/// Profile and settings.
///
/// One screen rather than a profile/settings split: there are a dozen controls
/// in total, and splitting them would mean two mostly-empty screens.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final isGuest = ref.watch(isGuestProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xxl),
              children: [
                _Header(user: user),
                if (isGuest) ...[Gap.h16, const _GuestUpgradeCard()],
                if (!isGuest && !user.emailVerified) ...[Gap.h16, const _VerifyEmailCard()],

                Gap.h24,
                const _SectionLabel('Account'),
                _Tile(
                  icon: Icons.badge_outlined,
                  title: 'Name',
                  value: user.displayName.isEmpty ? 'Not set' : user.displayName,
                  onTap: () => showEditNameSheet(context, ref, current: user.displayName),
                ),
                _ClassTile(user: user),

                Gap.h24,
                const _SectionLabel('Notifications'),
                _NotificationSwitches(user: user),

                Gap.h24,
                const _SectionLabel('Appearance'),
                const _ThemeSelector(),

                Gap.h24,
                const _SectionLabel('Offline'),
                const _OfflineMapTile(),

                Gap.h32,
                const _SignOutButton(),
              ],
            ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: theme.colorScheme.primary,
          child: Text(
            user.initials,
            style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.onPrimary),
          ),
        ),
        Gap.w16,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.displayName.isEmpty ? 'Guest' : user.displayName,
                style: theme.textTheme.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                user.email.isEmpty ? 'No account — browsing as a guest' : user.email,
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Gap.h8,
              Container(
                padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: Radii.pill,
                ),
                child: Text(
                  user.role.label,
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A guest's data lives only on this device — say so, and offer the fix.
class _GuestUpgradeCard extends StatelessWidget {
  const _GuestUpgradeCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: Radii.md,
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('You\'re browsing as a guest', style: theme.textTheme.titleMedium),
          Gap.h8,
          Text(
            'Anything you post stays on this phone only. Create an account and '
            'it moves with you — your reports and orders come along.',
            style: theme.textTheme.bodySmall,
          ),
          Gap.h16,
          CButton(
            label: 'Create an account',
            icon: Icons.person_add_alt_rounded,
            onPressed: () => context.push(Routes.register),
          ),
        ],
      ),
    );
  }
}

class _VerifyEmailCard extends ConsumerStatefulWidget {
  const _VerifyEmailCard();

  @override
  ConsumerState<_VerifyEmailCard> createState() => _VerifyEmailCardState();
}

class _VerifyEmailCardState extends ConsumerState<_VerifyEmailCard> {
  bool _sending = false;
  bool _sent = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: Radii.md,
      ),
      child: Row(
        children: [
          Icon(Icons.mark_email_unread_outlined, size: 20, color: theme.colorScheme.primary),
          Gap.w12,
          Expanded(
            child: Text(
              _sent ? 'Verification email sent.' : 'Your email isn\'t verified yet.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          if (!_sent)
            TextButton(
              onPressed: _sending
                  ? null
                  : () async {
                      setState(() => _sending = true);
                      final ok = await ref.read(authControllerProvider.notifier).resendVerification();
                      if (mounted) setState(() { _sending = false; _sent = ok; });
                    },
              child: Text(_sending ? 'Sending…' : 'Resend'),
            ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Text(label, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, this.value, this.onTap, this.subtitle});

  final IconData icon;
  final String title;
  final String? value;
  final String? subtitle;
  final VoidCallback? onTap;

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
          decoration: BoxDecoration(
            borderRadius: Radii.md,
            border: Border.all(color: theme.colorScheme.outline),
          ),
          padding: const EdgeInsets.all(Gap.md),
          margin: const EdgeInsets.only(bottom: Gap.sm),
          child: Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              Gap.w16,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.bodyMedium),
                    if (value != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        value!,
                        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: theme.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassTile extends ConsumerWidget {
  const _ClassTile({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = ref.watch(allSectionsProvider).valueOrNull ?? const [];
    final current = sections.where((s) => s.id == user.sectionId).firstOrNull;

    return _Tile(
      icon: Icons.school_outlined,
      title: 'Class',
      value: current?.name ?? (user.sectionId == null ? 'Not set' : user.sectionId!),
      onTap: () => showSectionPicker(context, ref),
    );
  }
}

class _NotificationSwitches extends ConsumerWidget {
  const _NotificationSwitches({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = user.notificationPrefs;
    final theme = Theme.of(context);

    /// Saves the preference, and — when a switch is being turned *on* — asks
    /// for the OS notification permission.
    ///
    /// Asking here rather than at first launch is deliberate: the prompt can
    /// only be shown once on Android, and a user who has just asked to be told
    /// about their print orders knows exactly what it is for. The preference is
    /// saved either way; a refused prompt leaves the inbox working and only
    /// push silent, which is what §7 says the split is for.
    Future<void> update(NotificationPrefs next, {required bool turningOn}) async {
      final ok = await ref.read(authControllerProvider.notifier).updateNotificationPrefs(next);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn\'t save that. Check your connection.')),
        );
        return;
      }

      if (!turningOn) return;

      final messaging = ref.read(messagingServiceProvider);
      if (await messaging.hasPermission()) return;

      final granted = await messaging.requestPermission();
      if (!context.mounted) return;

      if (granted) {
        // The token only becomes available once permission exists, so register
        // it now instead of waiting for the next sign-in.
        ref.invalidate(tokenRegistrarProvider);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Notifications are blocked for Campus360, so these will only show '
              'inside the app. Enable them in Settings to get alerts.',
            ),
          ),
        );
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: Radii.md,
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Lost & Found'),
            subtitle: const Text('Matches, claims and returns'),
            value: prefs.lostFound,
            onChanged: (v) => update(prefs.copyWith(lostFound: v), turningOn: v),
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text('Print orders'),
            subtitle: const Text('When your printout is ready'),
            value: prefs.print,
            onChanged: (v) => update(prefs.copyWith(print: v), turningOn: v),
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text('Campus alerts'),
            subtitle: const Text('Important campus-wide notices'),
            value: prefs.pulse,
            onChanged: (v) => update(prefs.copyWith(pulse: v), turningOn: v),
          ),
        ],
      ),
    );
  }
}

class _ThemeSelector extends ConsumerWidget {
  const _ThemeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(Gap.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: Radii.md,
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: SegmentedButton<ThemeMode>(
        segments: const [
          ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto_rounded)),
          ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_rounded)),
          ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_rounded)),
        ],
        selected: {mode},
        onSelectionChanged: (s) => ref.read(themeModeProvider.notifier).set(s.first),
        showSelectedIcon: false,
      ),
    );
  }
}

/// Saved map size, and a way in to manage it. Ties the offline map to a place
/// where a user would look for "why is this app using storage".
class _OfflineMapTile extends StatefulWidget {
  const _OfflineMapTile();

  @override
  State<_OfflineMapTile> createState() => _OfflineMapTileState();
}

class _OfflineMapTileState extends State<_OfflineMapTile> {
  int _tiles = 0;
  int _bytes = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final cache = await TileCache.instance();
    final tiles = await cache.tileCount();
    final bytes = await cache.sizeBytes();
    if (mounted) setState(() { _tiles = tiles; _bytes = bytes; });
  }

  @override
  Widget build(BuildContext context) {
    return _Tile(
      icon: Icons.map_outlined,
      title: 'Saved campus map',
      value: _tiles == 0 ? 'Not downloaded' : '$_tiles tiles · ${Fmt.fileSize(_bytes)}',
      subtitle: 'Lets the map work without a network',
      onTap: () async {
        await showMapDownloadSheet(context);
        await _refresh();
      },
    );
  }
}

class _SignOutButton extends ConsumerWidget {
  const _SignOutButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuest = ref.watch(isGuestProvider);

    return CButton(
      label: 'Sign out',
      icon: Icons.logout_rounded,
      variant: CButtonVariant.outlined,
      onPressed: () async {
        // A guest signing out loses everything, because an anonymous account
        // cannot be signed back into. That deserves a warning, not a shrug.
        final confirmed = !isGuest ||
            (await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Sign out of guest mode?'),
                    content: const Text(
                      'Guest sessions can\'t be signed back into. Anything you '
                      'posted from this phone will no longer be yours to manage.',
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign out')),
                    ],
                  ),
                ) ??
                false);

        if (!confirmed) return;

        // Hand the device's push token to sign-out so it is removed from this
        // account first (§6). Skipping it would leave the next person to sign
        // in on this phone receiving the previous user's notifications.
        final token = await ref.read(messagingServiceProvider).token();
        await ref.read(authControllerProvider.notifier).signOut(fcmToken: token);
        // The router's redirect takes it from here.
      },
    );
  }
}

/// Shown when the profile can't load at all.
class ProfileErrorView extends StatelessWidget {
  const ProfileErrorView({super.key, required this.failure});
  final AppFailure failure;

  @override
  Widget build(BuildContext context) => ErrorStateView(failure: failure);
}
