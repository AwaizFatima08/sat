/// Typed result for recoverable I/O. Switch exhaustively; never throw.
sealed class Result<T, F> {
  const Result();
}

final class Ok<T, F> extends Result<T, F> {
  const Ok(this.value);
  final T value;
}

final class Err<T, F> extends Result<T, F> {
  const Err(this.failure);
  final F failure;
}

/// Stable failure codes for anything that talks to the network or an SDK.
enum FailureCode {
  cancelled,
  network,
  wrongPassword,
  userNotFound,
  emailInUse,
  weakPassword,
  invalidEmail,
  requiresRecentLogin,
  credentialInUse,
  unknown,
}

class AppFailure {
  const AppFailure(this.code, [this.detail]);
  final FailureCode code;
  final String? detail;

  /// Plain-English message for a snackbar.
  String get message => switch (code) {
    FailureCode.cancelled => 'Cancelled.',
    FailureCode.network =>
      'No internet connection. Try again when you are online.',
    FailureCode.wrongPassword => 'That email and password do not match.',
    FailureCode.userNotFound => 'No account uses that email yet.',
    FailureCode.emailInUse =>
      'An account already uses that email. Sign in instead.',
    FailureCode.weakPassword => 'Choose a password of at least 8 characters.',
    FailureCode.invalidEmail => 'That email address does not look right.',
    FailureCode.requiresRecentLogin =>
      'For your security, sign in again and then retry.',
    FailureCode.credentialInUse =>
      'That Google account already has a Module Up account. Sign out and sign in with it.',
    FailureCode.unknown => 'Something went wrong. Please try again.',
  };
}
