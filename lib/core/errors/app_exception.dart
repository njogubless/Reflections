import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';

enum AppErrorKind {
  validation,
  permission,
  network,
  notFound,
  conflict,
  auth,
  unexpected,
}

/// Application-level error. Its [message] is always safe to show to users;
/// raw Firebase exception text never reaches the UI.
class AppException implements Exception {
  const AppException(this.kind, this.message, {this.cause});

  const AppException.validation(String message)
    : this(AppErrorKind.validation, message);
  const AppException.permission([String message = _permissionMessage])
    : this(AppErrorKind.permission, message);
  const AppException.notFound([
    String message = 'This item is no longer available.',
  ]) : this(AppErrorKind.notFound, message);
  const AppException.conflict(String message)
    : this(AppErrorKind.conflict, message);

  static const _permissionMessage = 'You do not have permission to do that.';

  final AppErrorKind kind;
  final String message;
  final Object? cause;

  bool get isRetryable =>
      kind == AppErrorKind.network || kind == AppErrorKind.unexpected;

  @override
  String toString() => 'AppException($kind): $message';

  /// Maps any thrown object to an [AppException] and logs diagnostics
  /// (codes only — never tokens, URLs, or user content).
  static AppException from(Object error, [StackTrace? stack]) {
    if (error is AppException) return error;
    final mapped = _map(error);
    developer.log(
      'AppException(${mapped.kind}) from ${error.runtimeType}'
      '${error is FirebaseException ? ' [${error.plugin}/${error.code}]' : ''}',
      name: 'devotion',
      error: error is FirebaseException ? null : error,
      stackTrace: stack,
    );
    return mapped;
  }

  static AppException _map(Object error) {
    if (error is FirebaseAuthException) return _mapAuth(error);
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
        case 'unauthorized':
        case 'unauthenticated':
          return AppException(
            AppErrorKind.permission,
            _permissionMessage,
            cause: error,
          );
        case 'not-found':
        case 'object-not-found':
          return AppException(
            AppErrorKind.notFound,
            'This item is no longer available.',
            cause: error,
          );
        case 'unavailable':
        case 'deadline-exceeded':
        case 'retry-limit-exceeded':
          return AppException(
            AppErrorKind.network,
            'Unable to reach the server. Check your connection and try again.',
            cause: error,
          );
        case 'already-exists':
          return AppException(
            AppErrorKind.conflict,
            'This item already exists.',
            cause: error,
          );
        case 'failed-precondition':
          return AppException(
            AppErrorKind.conflict,
            'This item changed while you were working. Refresh and try again.',
            cause: error,
          );
        case 'canceled':
          return AppException(
            AppErrorKind.unexpected,
            'The operation was cancelled.',
            cause: error,
          );
        case 'quota-exceeded':
          return AppException(
            AppErrorKind.unexpected,
            'Storage limit reached. Please try again later.',
            cause: error,
          );
      }
    }
    if (error is SocketException || error is TimeoutException) {
      return AppException(
        AppErrorKind.network,
        'Unable to reach the server. Check your connection and try again.',
        cause: error,
      );
    }
    return AppException(
      AppErrorKind.unexpected,
      'Something went wrong. Please try again.',
      cause: error,
    );
  }

  static AppException _mapAuth(FirebaseAuthException e) {
    final message = switch (e.code) {
      'invalid-email' => 'Enter a valid email address.',
      'user-disabled' => 'This account has been disabled.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' ||
      'INVALID_LOGIN_CREDENTIALS' => 'Incorrect email or password.',
      'email-already-in-use' => 'An account already exists for that email.',
      'weak-password' => 'Choose a stronger password (at least 8 characters).',
      'too-many-requests' =>
        'Too many attempts. Please wait a moment and try again.',
      'network-request-failed' =>
        'Unable to reach the server. Check your connection and try again.',
      'requires-recent-login' =>
        'Please sign in again to complete this action.',
      _ => 'Unable to complete sign-in. Please try again.',
    };
    final kind = e.code == 'network-request-failed'
        ? AppErrorKind.network
        : AppErrorKind.auth;
    return AppException(kind, message, cause: e);
  }
}

/// Convenience: run [action], converting failures to [AppException].
Future<T> guard<T>(Future<T> Function() action) async {
  try {
    return await action();
  } catch (e, s) {
    throw AppException.from(e, s);
  }
}
