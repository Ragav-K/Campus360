import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/constants/firestore_paths.dart';
import '../core/errors/app_failure.dart';
import '../core/errors/failure_mapper.dart';
import '../core/utils/validators.dart';
import '../models/app_user.dart';

/// Owns authentication and the `users/{uid}` profile document.
///
/// Note on roles: this repository can *read* the role but never writes one.
/// Elevation to staff/admin happens through the `setUserRole` callable, which
/// also sets the custom claim that security rules actually trust (§6).
class AuthRepository {
  AuthRepository(this._auth, this._db);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentAuthUser => _auth.currentUser;
  String? get uid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) => _db.collection(Paths.users).doc(uid);

  /// Live profile stream. Emits null while the `onCreate` function is still
  /// writing the document immediately after registration.
  Stream<AppUser?> watchUser(String uid) => _userDoc(uid).snapshots().map((snap) {
        if (!snap.exists) return null;
        return _fromDoc(snap.id, snap.data()!);
      });

  Future<AppUser?> fetchUser(String uid) => FailureMapper.guard(() async {
        final snap = await _userDoc(uid).get();
        return snap.exists ? _fromDoc(snap.id, snap.data()!) : null;
      });

  /// Signs in, then enforces the campus email domain.
  ///
  /// [allowedDomains] comes from `config/app`. The registration form already
  /// checks it, but sign-in must too: any account created before the rule was
  /// switched on, or through the public Auth API directly, would otherwise walk
  /// straight in.
  Future<void> signIn({
    required String email,
    required String password,
    List<String> allowedDomains = const [],
  }) =>
      FailureMapper.guard(() async {
        final cred = await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
        final user = cred.user;

        // Same validator the form uses, so the two can never disagree.
        if (allowedDomains.isNotEmpty) {
          final rejection = Validators.email(user?.email ?? email, allowedDomains: allowedDomains);
          if (rejection != null) {
            await _auth.signOut();
            throw AppFailure(
              kind: FailureKind.auth,
              message: 'Campus360 is only for college accounts. $rejection',
              isRetryable: false,
            );
          }
        }

        if (user != null) await ensureUserDocument(user);
        await _touchLastSeen();
      });

  /// Recreates `users/{uid}` if it is missing.
  ///
  /// An account can exist in Firebase Auth without a profile document: the
  /// account is created first, and the Firestore write immediately after can
  /// fail (offline, rules, misconfiguration). Without this the user is stranded
  /// — signed in, but with no profile the app can read, and no way back.
  ///
  /// Creates only a *student* or *guest* profile, and merges so it can never
  /// downgrade the role of an existing staff/admin document.
  ///
  /// The anonymous check matters: without it every guest would be written into
  /// Firestore as a student, and the app would lose any way to tell a visitor
  /// from a registered student.
  Future<void> ensureUserDocument(User user) async {
    try {
      final doc = _userDoc(user.uid);
      final snap = await doc.get();
      if (snap.exists) return;

      final isGuest = user.isAnonymous;

      await doc.set({
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName ?? user.email?.split('@').first ?? (isGuest ? 'Guest' : ''),
        'role': isGuest ? UserRole.guest.name : UserRole.student.name,
        'isAnonymous': isGuest,
        'notificationPrefs': const NotificationPrefs().toMap(),
        'disabled': false,
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Never block sign-in on this. If it fails the profile stream stays null
      // and the UI shows its "couldn't load profile" state, and the next
      // sign-in retries.
    }
  }

  /// Creates the account, sets the display name, sends verification, and
  /// creates the profile document with `role: student`.
  ///
  /// The profile write is *also* performed by an `onCreate` Auth trigger
  /// server-side; whichever lands first wins via `SetOptions(merge: true)`.
  /// Doing it here too means the app is usable before Functions are deployed.
  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) =>
      FailureMapper.guard(() async {
        final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
        final user = cred.user;
        if (user == null) throw AppFailure.unknown;

        await user.updateDisplayName(displayName.trim());

        await _userDoc(user.uid).set({
          'uid': user.uid,
          'email': user.email,
          'displayName': displayName.trim(),
          'role': UserRole.student.name,
          'notificationPrefs': const NotificationPrefs().toMap(),
          'disabled': false,
          'createdAt': FieldValue.serverTimestamp(),
          'lastSeenAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await sendVerificationEmail();
      });

  /// Signs in a campus visitor anonymously.
  ///
  /// Anonymous auth rather than opening the database to unauthenticated reads:
  /// a guest gets a real uid, so every `signedIn()` security rule keeps working
  /// and a guest owns their own reports and orders.
  Future<void> signInAsGuest() => FailureMapper.guard(() async {
        final cred = await _auth.signInAnonymously();
        final user = cred.user;
        if (user != null) await ensureUserDocument(user);
      });

  /// Turns the current guest into a permanent account, **keeping the same uid**
  /// so everything they already reported or ordered stays theirs.
  ///
  /// Creating a fresh account instead would silently orphan a guest's history —
  /// the worst failure mode of letting guests write at all.
  Future<void> linkGuestToEmail({
    required String email,
    required String password,
    required String displayName,
  }) =>
      FailureMapper.guard(() async {
        final user = _auth.currentUser;
        if (user == null || !user.isAnonymous) {
          throw const AppFailure(
            kind: FailureKind.auth,
            message: 'You are already signed in with an account.',
            isRetryable: false,
          );
        }

        final credential = EmailAuthProvider.credential(email: email.trim(), password: password);
        await user.linkWithCredential(credential);
        await user.updateDisplayName(displayName.trim());

        await _userDoc(user.uid).set({
          'email': email.trim(),
          'displayName': displayName.trim(),
          'role': UserRole.student.name,
          'isAnonymous': false,
        }, SetOptions(merge: true));

        await sendVerificationEmail();
      });

  /// Name and phone for a guest, collected before their first write so a print
  /// shop or a finder has someone to contact.
  Future<void> setGuestIdentity({required String name, String? phone}) =>
      FailureMapper.guard(() async {
        final id = uid;
        if (id == null) throw AppFailure.permission;
        await _userDoc(id).set({
          'displayName': name.trim(),
          if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        }, SetOptions(merge: true));
        await _auth.currentUser?.updateDisplayName(name.trim());
      });

  /// The class timetable this user follows, e.g. "cse-3a".
  Future<void> setSection(String? sectionId) => FailureMapper.guard(() async {
        final id = uid;
        if (id == null) throw AppFailure.permission;
        await _userDoc(id).set({'sectionId': sectionId}, SetOptions(merge: true));
      });

  Future<void> sendVerificationEmail() => FailureMapper.guard(() async {
        final user = _auth.currentUser;
        if (user == null || user.emailVerified) return;
        await user.sendEmailVerification();
      });

  /// Firebase caches `emailVerified`; force a reload before trusting it.
  Future<bool> refreshEmailVerified() => FailureMapper.guard(() async {
        final user = _auth.currentUser;
        if (user == null) return false;
        await user.reload();
        return _auth.currentUser?.emailVerified ?? false;
      });

  Future<void> sendPasswordReset(String email) => FailureMapper.guard(
        () => _auth.sendPasswordResetEmail(email: email.trim()),
      );

  /// Removes this device's FCM token before signing out, so the next person to
  /// use the device does not receive the previous user's notifications.
  Future<void> signOut({String? fcmToken}) => FailureMapper.guard(() async {
        final id = uid;
        if (id != null && fcmToken != null) {
          try {
            await _userDoc(id).update({
              'fcmTokens': FieldValue.arrayRemove([fcmToken])
            });
          } catch (_) {
            // Best-effort: never block sign-out on a token cleanup failure.
          }
        }
        await _auth.signOut();
      });

  Future<void> updateProfile({String? displayName, String? photoUrl}) => FailureMapper.guard(() async {
        final id = uid;
        if (id == null) throw AppFailure.permission;
        await _userDoc(id).update({
          if (displayName != null) 'displayName': displayName.trim(),
          if (photoUrl != null) 'photoUrl': photoUrl,
        });
        if (displayName != null) await _auth.currentUser?.updateDisplayName(displayName.trim());
      });

  Future<void> updateNotificationPrefs(NotificationPrefs prefs) => FailureMapper.guard(() async {
        final id = uid;
        if (id == null) throw AppFailure.permission;
        await _userDoc(id).update({'notificationPrefs': prefs.toMap()});
      });

  Future<void> registerFcmToken(String token) => FailureMapper.guard(() async {
        final id = uid;
        if (id == null) return;
        await _userDoc(id).update({
          'fcmTokens': FieldValue.arrayUnion([token])
        });
      });

  Future<void> _touchLastSeen() async {
    final id = uid;
    if (id == null) return;
    try {
      await _userDoc(id).update({'lastSeenAt': FieldValue.serverTimestamp()});
    } catch (_) {
      // Non-critical.
    }
  }

  AppUser _fromDoc(String id, Map<String, dynamic> d) => AppUser(
        uid: id,
        email: d['email'] as String? ?? '',
        displayName: d['displayName'] as String? ?? '',
        role: UserRole.fromName(d['role'] as String?),
        photoUrl: d['photoUrl'] as String?,
        shopId: d['shopId'] as String?,
        notificationPrefs: NotificationPrefs.fromMap(d['notificationPrefs'] as Map<String, dynamic>?),
        emailVerified: _auth.currentUser?.emailVerified ?? false,
        disabled: d['disabled'] as bool? ?? false,
        createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
        // Trust the live session over the stored flag — linking an account
        // clears it on the client before the document write lands.
        isAnonymous: _auth.currentUser?.isAnonymous ?? (d['isAnonymous'] as bool? ?? false),
        phone: d['phone'] as String?,
        sectionId: d['sectionId'] as String?,
      );
}
