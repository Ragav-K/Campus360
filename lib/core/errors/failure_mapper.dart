import 'dart:async';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'app_failure.dart';

/// Single translation point from platform errors to [AppFailure].
/// Every repository funnels through [guard] so no screen ever has to think
/// about Firebase error codes.
abstract final class FailureMapper {
  static AppFailure map(Object error, [StackTrace? stack]) {
    if (error is AppFailure) return error;

    if (error is SocketException || error is TimeoutException) {
      return AppFailure.offline;
    }

    if (error is FirebaseAuthException) return _auth(error);
    if (error is FirebaseFunctionsException) return _functions(error);
    if (error is FirebaseException) return _firebase(error);

    return AppFailure(
        kind: FailureKind.unknown,
        message: AppFailure.unknown.message,
        debug: error.toString());
  }

  /// Wraps an async operation, rethrowing everything as [AppFailure].
  static Future<T> guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } catch (e, s) {
      throw map(e, s);
    }
  }

  static AppFailure _auth(FirebaseAuthException e) {
    final message = switch (e.code) {
      'invalid-email' => 'That email address looks incorrect.',
      'user-disabled' =>
        'This account has been disabled. Contact the campus office.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' =>
        'Incorrect email or password.',
      'email-already-in-use' =>
        'An account already exists for this email. Try signing in.',
      'weak-password' => 'Choose a stronger password — at least 8 characters.',
      'too-many-requests' =>
        'Too many attempts. Wait a few minutes and try again.',
      'network-request-failed' => AppFailure.offline.message,
      'requires-recent-login' =>
        'Please sign in again to complete this action.',
      'admin-restricted-operation' =>
        'Guest access is not enabled yet. Sign in with your college account for now.',
      'operation-not-allowed' => 'Email sign-in is not enabled for this app.',
      _ => 'Sign-in failed. Please try again.',
    };
    final kind = e.code == 'network-request-failed'
        ? FailureKind.network
        : FailureKind.auth;
    return AppFailure(
      kind: kind,
      message: message,
      debug: '${e.code}: ${e.message}',
      isRetryable: e.code != 'admin-restricted-operation',
    );
  }

  static AppFailure _functions(FirebaseFunctionsException e) {
    // Callables carry our own domain codes in `details`, e.g. {code: 'otp/expired'}.
    final domain =
        (e.details is Map) ? (e.details as Map)['code']?.toString() : null;

    return switch (domain) {
      'otp/invalid' => const AppFailure(
          kind: FailureKind.otpInvalid,
          message: 'That code is not correct. Check the digits and try again.',
        ),
      'otp/expired' => const AppFailure(
          kind: FailureKind.otpExpired,
          message:
              'This pickup code has expired. Ask the student to refresh it in their app.',
          isRetryable: false,
        ),
      'otp/used' => const AppFailure(
          kind: FailureKind.otpUsed,
          message: 'This code has already been used. The order was collected.',
          isRetryable: false,
        ),
      'otp/locked' => const AppFailure(
          kind: FailureKind.rateLimited,
          message:
              'Too many incorrect attempts. Verification is locked for this order.',
          isRetryable: false,
        ),
      'order/badStatus' => const AppFailure(
          kind: FailureKind.conflict,
          message: 'This order is not ready for pickup.',
          isRetryable: false,
        ),
      'claim/alreadyResolved' => const AppFailure(
          kind: FailureKind.conflict,
          message: 'This claim was already decided by someone else.',
          isRetryable: false,
        ),
      _ => _functionsByCode(e),
    };
  }

  static AppFailure _functionsByCode(FirebaseFunctionsException e) {
    final message = switch (e.code) {
      'unauthenticated' => 'Please sign in again.',
      'permission-denied' => AppFailure.permission.message,
      'not-found' => AppFailure.notFound.message,
      'failed-precondition' => 'This action is no longer available.',
      'resource-exhausted' => 'Too many requests. Please wait a moment.',
      'unavailable' || 'deadline-exceeded' => AppFailure.offline.message,
      _ => AppFailure.unknown.message,
    };
    final kind = switch (e.code) {
      'unauthenticated' => FailureKind.auth,
      'permission-denied' => FailureKind.permission,
      'not-found' => FailureKind.notFound,
      'failed-precondition' => FailureKind.conflict,
      'resource-exhausted' => FailureKind.rateLimited,
      'unavailable' || 'deadline-exceeded' => FailureKind.network,
      _ => FailureKind.unknown,
    };
    return AppFailure(
        kind: kind, message: message, debug: '${e.code}: ${e.message}');
  }

  static AppFailure _firebase(FirebaseException e) {
    // Storage-specific first.
    if (e.plugin == 'firebase_storage') {
      final message = switch (e.code) {
        'unauthorized' => "You don't have permission to upload this file.",
        'canceled' => 'Upload cancelled.',
        'quota-exceeded' => 'Storage is full. Contact the campus office.',
        'retry-limit-exceeded' =>
          'The upload timed out. Check your connection and try again.',
        // On a download this means the file is gone; on an upload it means the
        // storage bucket itself is missing. Worded to be true of both, because
        // the mapper cannot tell which direction it was called from.
        'object-not-found' =>
          'That file is not in storage. If this keeps happening, tell the campus office.',
        _ => "The file couldn't be uploaded. Please try again.",
      };
      return AppFailure(
          kind: FailureKind.upload,
          message: message,
          debug: '${e.code}: ${e.message}');
    }

    final message = switch (e.code) {
      'permission-denied' => AppFailure.permission.message,
      'not-found' => AppFailure.notFound.message,
      'unavailable' => AppFailure.offline.message,
      'already-exists' => 'That already exists.',
      'aborted' ||
      'failed-precondition' =>
        'Someone else changed this first. Refresh and try again.',
      'resource-exhausted' => 'The service is busy. Please try again shortly.',
      'deadline-exceeded' =>
        'That took too long. Check your connection and try again.',
      _ => AppFailure.unknown.message,
    };
    final kind = switch (e.code) {
      'permission-denied' => FailureKind.permission,
      'not-found' => FailureKind.notFound,
      'unavailable' || 'deadline-exceeded' => FailureKind.network,
      'aborted' ||
      'failed-precondition' ||
      'already-exists' =>
        FailureKind.conflict,
      'resource-exhausted' => FailureKind.rateLimited,
      _ => FailureKind.unknown,
    };
    return AppFailure(
        kind: kind, message: message, debug: '${e.code}: ${e.message}');
  }
}
