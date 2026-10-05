import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../../core/services/firebase_providers.dart';
import '../../../models/app_user.dart';
import '../../../repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(firebaseAuthProvider), ref.watch(firestoreProvider)),
);

/// Raw Firebase auth state. The router listens to this.
final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

/// The signed-in user's profile document, or null when signed out.
///
/// If the account is authenticated but has no profile document — possible when
/// the write at registration failed — this repairs it once, rather than
/// leaving the user permanently profile-less. The stream then re-emits with
/// the created document.
final currentUserProvider = StreamProvider<AppUser?>((ref) {
  final auth = ref.watch(authStateProvider).valueOrNull;
  if (auth == null) return Stream.value(null);

  final repo = ref.watch(authRepositoryProvider);
  var repairAttempted = false;

  return repo.watchUser(auth.uid).map((user) {
    if (user == null && !repairAttempted) {
      repairAttempted = true;
      repo.ensureUserDocument(auth);
    }
    return user;
  });
});

/// Convenience: the role, defaulting to student while the profile loads.
final currentRoleProvider = Provider<UserRole>(
  (ref) => ref.watch(currentUserProvider).valueOrNull?.role ?? UserRole.student,
);

final isSignedInProvider = Provider<bool>(
  (ref) => ref.watch(authStateProvider).valueOrNull != null,
);

/// True when browsing as a campus visitor rather than a registered account.
final isGuestProvider = Provider<bool>(
  (ref) => ref.watch(authStateProvider).valueOrNull?.isAnonymous ?? false,
);

/// Drives login / register / reset forms. Exposes AsyncValue<void> so buttons
/// get their loading + disabled state for free (§33).
class AuthController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<bool> signIn(String email, String password) => _run(
        () => _repo.signIn(
          email: email,
          password: password,
          // Live from config/app, so the campus can change or lift the
          // restriction without shipping a new build.
          allowedDomains: ref.read(remoteConfigValueProvider).enforcedDomains,
        ),
      );

  Future<bool> register({required String email, required String password, required String name}) {
    // A guest registering must be *linked*, not replaced, so their existing
    // reports and orders survive the upgrade.
    final current = _repo.currentAuthUser;
    if (current != null && current.isAnonymous) {
      return _run(() => _repo.linkGuestToEmail(email: email, password: password, displayName: name));
    }
    return _run(() => _repo.register(email: email, password: password, displayName: name));
  }

  Future<bool> continueAsGuest() => _run(() => _repo.signInAsGuest());

  Future<bool> setGuestIdentity({required String name, String? phone}) =>
      _run(() => _repo.setGuestIdentity(name: name, phone: phone));

  Future<bool> setSection(String? sectionId) => _run(() => _repo.setSection(sectionId));

  Future<bool> sendPasswordReset(String email) => _run(() => _repo.sendPasswordReset(email));

  Future<bool> resendVerification() => _run(() => _repo.sendVerificationEmail());

  Future<bool> signOut({String? fcmToken}) => _run(() => _repo.signOut(fcmToken: fcmToken));

  Future<bool> updateName(String name) => _run(() => _repo.updateProfile(displayName: name));

  Future<bool> updateNotificationPrefs(NotificationPrefs prefs) =>
      _run(() => _repo.updateNotificationPrefs(prefs));

  /// Runs [action], parking any [AppFailure] in [state] and returning whether
  /// it succeeded — so callers can navigate only on success.
  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncValue.loading();
    try {
      await action();
      state = const AsyncValue.data(null);
      return true;
    } catch (e, s) {
      state = AsyncValue.error(FailureMapper.map(e, s), s);
      return false;
    }
  }

  /// Drops any parked failure. The auth screens share this controller, so
  /// without this an error raised on sign-in greets the user again on the
  /// register screen, describing something they never did.
  void clearError() {
    if (state.hasError) state = const AsyncValue.data(null);
  }

  AppFailure? get failure {
    final e = state.error;
    return e is AppFailure ? e : (e == null ? null : AppFailure.unknown);
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(AuthController.new);
