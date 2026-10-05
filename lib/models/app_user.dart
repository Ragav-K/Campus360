/// Roles. Persisted as the enum name, and mirrored into Firebase Auth custom
/// claims by a Cloud Function — security rules trust only the claim (§6).
enum UserRole {
  student,

  /// A campus visitor using the app without registering, via Firebase
  /// anonymous auth. Has the same abilities as a student by product decision —
  /// see the guest-mode section of ARCHITECTURE.md.
  guest,

  /// Desk operator for the crowd-counter dashboard. Can only write crowd
  /// occupancy documents — see `isValidCrowdWrite` in firestore.rules.
  crowdCounter,

  printShopStaff,
  admin;

  static UserRole fromName(String? name) =>
      UserRole.values.where((r) => r.name == name).firstOrNull ?? UserRole.student;

  bool get isStaff => this == UserRole.printShopStaff || this == UserRole.admin;
  bool get isAdmin => this == UserRole.admin;
  bool get canCountCrowds => this == UserRole.crowdCounter || this == UserRole.admin;

  /// Can report items and place print orders. Guests included, by decision.
  bool get canAct => this == UserRole.student || this == UserRole.guest || this == UserRole.admin;

  String get label => switch (this) {
        UserRole.student => 'Student',
        UserRole.guest => 'Guest',
        UserRole.crowdCounter => 'Campus desk',
        UserRole.printShopStaff => 'Print shop staff',
        UserRole.admin => 'Campus admin',
      };
}

class NotificationPrefs {
  const NotificationPrefs({this.lostFound = true, this.print = true, this.pulse = true});

  final bool lostFound;
  final bool print;
  final bool pulse;

  factory NotificationPrefs.fromMap(Map<String, dynamic>? m) => NotificationPrefs(
        lostFound: m?['lostFound'] as bool? ?? true,
        print: m?['print'] as bool? ?? true,
        pulse: m?['pulse'] as bool? ?? true,
      );

  Map<String, dynamic> toMap() => {'lostFound': lostFound, 'print': print, 'pulse': pulse};

  NotificationPrefs copyWith({bool? lostFound, bool? print, bool? pulse}) => NotificationPrefs(
        lostFound: lostFound ?? this.lostFound,
        print: print ?? this.print,
        pulse: pulse ?? this.pulse,
      );
}

/// The `users/{uid}` document. Pure Dart — Firestore mapping lives in
/// `repositories/dto/user_dto.dart`.
class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.photoUrl,
    this.shopId,
    this.notificationPrefs = const NotificationPrefs(),
    this.emailVerified = false,
    this.disabled = false,
    this.createdAt,
    this.isAnonymous = false,
    this.phone,
    this.sectionId,
  });

  final String uid;
  final String email;
  final String displayName;
  final UserRole role;
  final String? photoUrl;

  /// Set when [role] is [UserRole.printShopStaff].
  final String? shopId;

  final NotificationPrefs notificationPrefs;
  final bool emailVerified;
  final bool disabled;
  final DateTime? createdAt;

  /// True for a guest signed in anonymously. Such an account lives only on this
  /// device — clearing app data loses it — so the UI nudges guests to upgrade
  /// once they have posted something.
  final bool isAnonymous;

  /// Collected from guests before their first write, so a print shop has
  /// someone to contact about a pickup.
  final String? phone;

  /// Which class timetable to show, e.g. "cse-3a". Null until chosen.
  final String? sectionId;

  bool get isGuest => role == UserRole.guest || isAnonymous;

  /// A guest who hasn't told us who they are yet.
  bool get needsIdentity => isGuest && (displayName.trim().isEmpty || displayName == 'Guest');

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return email.isNotEmpty ? email[0].toUpperCase() : '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  AppUser copyWith({
    String? displayName,
    String? photoUrl,
    UserRole? role,
    String? shopId,
    NotificationPrefs? notificationPrefs,
    bool? emailVerified,
    String? phone,
    String? sectionId,
  }) =>
      AppUser(
        uid: uid,
        email: email,
        displayName: displayName ?? this.displayName,
        role: role ?? this.role,
        photoUrl: photoUrl ?? this.photoUrl,
        shopId: shopId ?? this.shopId,
        notificationPrefs: notificationPrefs ?? this.notificationPrefs,
        emailVerified: emailVerified ?? this.emailVerified,
        disabled: disabled,
        createdAt: createdAt,
        isAnonymous: isAnonymous,
        phone: phone ?? this.phone,
        sectionId: sectionId ?? this.sectionId,
      );
}
