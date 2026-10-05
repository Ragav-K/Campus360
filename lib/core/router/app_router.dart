import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_providers.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/admin/screens/survey_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/campus_map/screens/location_detail_screen.dart';
import '../../features/campus_map/screens/map_home_screen.dart';
import '../../features/campus_map/screens/navigate_screen.dart';
import '../../features/campus_pulse/screens/pulse_detail_screen.dart';
import '../../features/campus_pulse/screens/pulse_home_screen.dart';
import '../../features/printout/screens/new_order_screen.dart';
import '../../features/printout/screens/order_detail_screen.dart';
import '../../features/lost_found/screens/found_item_detail_screen.dart';
import '../../features/lost_found/screens/lost_found_home_screen.dart';
import '../../features/lost_found/screens/my_reports_screen.dart';
import '../../features/lost_found/screens/report_item_screen.dart';
import '../../features/printout/screens/print_home_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/timetable/screens/timetable_screen.dart';
import '../../models/app_user.dart';
import '../constants/routes.dart';

/// Rebuilds the router's redirect whenever auth state changes.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    _sub = ref.listen(authStateProvider, (_, __) => notifyListeners(), fireImmediately: false);
  }
  late final ProviderSubscription _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    debugLogDiagnostics: false,

    // Route guards are UX, not security. The real boundary is Firestore rules.
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final here = state.matchedLocation;

      // Hold on /splash until we know whether anyone is signed in — avoids a
      // login-screen flash on cold start with a cached session.
      if (auth.isLoading) return here == Routes.splash ? null : Routes.splash;

      final signedIn = auth.valueOrNull != null;
      final onAuthScreen = here == Routes.login || here == Routes.register || here == Routes.forgotPassword;

      if (!signedIn) return onAuthScreen ? null : Routes.login;
      if (onAuthScreen || here == Routes.splash) return Routes.pulse;

      final role = ref.read(currentRoleProvider);
      if (here.startsWith(Routes.adminHome) && role != UserRole.admin) return Routes.pulse;
      if (here.startsWith(Routes.staffHome) && !role.isStaff) return Routes.pulse;

      return null;
    },

    routes: [
      GoRoute(path: Routes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(path: Routes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(path: Routes.register, builder: (_, __) => const RegisterScreen()),
      GoRoute(path: Routes.forgotPassword, builder: (_, __) => const ForgotPasswordScreen()),

      // Full-screen, above the tab shell — reached from the Pulse "Today" card.
      GoRoute(path: Routes.timetable, builder: (_, __) => const TimetableScreen()),

      // Profile and settings, reached from the top bar of any tab.
      GoRoute(path: Routes.profile, builder: (_, __) => const ProfileScreen()),

      // The notification inbox, reached from the bell in the Pulse header.
      GoRoute(
        path: Routes.notifications,
        builder: (_, __) => const NotificationsScreen(),
      ),

      // Admin survey. The redirect above already blocks /admin/** for
      // non-admins; this is the UX gate, the rules are the real one.
      GoRoute(path: Routes.adminSurvey, builder: (_, __) => const SurveyScreen()),

      // The four-tab shell. Tab state survives navigation between branches.
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.pulse,
              builder: (_, __) => const PulseHomeScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (_, state) => PulseDetailScreen(pulseId: state.pathParameters['id']!),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.map,
              builder: (_, __) => const MapHomeScreen(),
              routes: [
                GoRoute(
                  path: 'location/:id',
                  builder: (_, state) => LocationDetailScreen(locationId: state.pathParameters['id']!),
                ),
                GoRoute(
                  path: 'navigate/:id',
                  builder: (_, state) => NavigateScreen(locationId: state.pathParameters['id']!),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.lostFound,
              builder: (_, __) => const LostFoundHomeScreen(),
              routes: [
                GoRoute(
                  path: 'report-lost',
                  builder: (_, __) => const ReportItemScreen(isLost: true),
                ),
                GoRoute(
                  path: 'report-found',
                  builder: (_, __) => const ReportItemScreen(isLost: false),
                ),
                GoRoute(path: 'mine', builder: (_, __) => const MyReportsScreen()),
                GoRoute(
                  path: 'found/:id',
                  builder: (_, state) =>
                      FoundItemDetailScreen(itemId: state.pathParameters['id']!),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.print,
              builder: (_, __) => const PrintHomeScreen(),
              routes: [
                GoRoute(path: 'new', builder: (_, __) => const NewOrderScreen()),
                GoRoute(
                  path: 'order/:id',
                  builder: (_, state) => OrderDetailScreen(orderId: state.pathParameters['id']!),
                ),
              ],
            ),
          ]),
        ],
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.explore_off_rounded, size: 40),
              const SizedBox(height: 12),
              Text('That screen doesn’t exist.', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => context.go(Routes.pulse), child: const Text('Back to Campus360')),
            ],
          ),
        ),
      ),
    ),
  );
});
