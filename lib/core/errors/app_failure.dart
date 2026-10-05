/// A user-presentable failure. Repositories throw these; UI renders
/// [message] directly. Raw Firebase errors never reach the user (§31).
class AppFailure implements Exception {
  const AppFailure({
    required this.kind,
    required this.message,
    this.debug,
    this.isRetryable = true,
  });

  final FailureKind kind;

  /// Plain-language, actionable, no jargon.
  final String message;

  /// Original error text — logged, never shown.
  final String? debug;

  final bool isRetryable;

  @override
  String toString() => 'AppFailure(${kind.name}: $message${debug == null ? '' : ' | $debug'})';

  // ---- Common constructors -------------------------------------------------

  static const offline = AppFailure(
    kind: FailureKind.network,
    message: "You're offline. Check your connection and try again.",
  );

  static const unknown = AppFailure(
    kind: FailureKind.unknown,
    message: 'Something went wrong. Please try again.',
  );

  static const permission = AppFailure(
    kind: FailureKind.permission,
    message: "You don't have permission to do that.",
    isRetryable: false,
  );

  static const notFound = AppFailure(
    kind: FailureKind.notFound,
    message: 'This item no longer exists. It may have been removed.',
    isRetryable: false,
  );
}

/// User-facing text for any thrown object.
///
/// For quick surfaces like a snackbar, where building a full error view would
/// be heavier than the message deserves.
String describeFailure(Object error) =>
    error is AppFailure ? error.message : AppFailure.unknown.message;

/// Narrows any thrown object to an [AppFailure] for the shared error views.
AppFailure describeAsFailure(Object error) =>
    error is AppFailure ? error : AppFailure.unknown;

enum FailureKind {
  network,
  auth,
  permission,
  notFound,
  validation,
  upload,
  fileTooLarge,
  unsupportedFile,
  otpInvalid,
  otpExpired,
  otpUsed,
  conflict,
  rateLimited,
  unknown,
}
