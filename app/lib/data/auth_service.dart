import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:moduleup/core/result.dart';

/// The signed-in student. Guests are anonymous Firebase users, upgraded in
/// place (same uid, same data) when they link Google or email.
class AppUser {
  const AppUser({
    required this.uid,
    required this.isGuest,
    this.email,
    this.displayName,
  });
  final String uid;
  final bool isGuest;
  final String? email;
  final String? displayName;
}

typedef AuthResult = Result<AppUser, AppFailure>;

abstract interface class AuthService {
  Stream<AppUser?> watch();
  AppUser? get current;
  Future<AuthResult> continueAsGuest();
  Future<AuthResult> signInWithGoogle();
  Future<AuthResult> signInWithEmail(String email, String password);

  /// Creates an email account, or upgrades the current guest to one.
  Future<AuthResult> registerWithEmail(String email, String password);
  Future<Result<void, AppFailure>> sendPasswordReset(String email);
  Future<void> signOut();

  /// Deletes the Firebase user. Data deletion happens first, in the repository.
  Future<Result<void, AppFailure>> deleteUser();
}

/// Web OAuth client from google-services.json (client_type 3), used to get an
/// ID token Firebase accepts.
const _serverClientId =
    '134818229060-4svtvtojbkkb48m84334v1o6lvgs74jd.apps.googleusercontent.com';

class FirebaseAuthService implements AuthService {
  FirebaseAuthService(this._auth);
  final FirebaseAuth _auth;
  bool _googleReady = false;

  static AppUser? _map(User? u) => u == null
      ? null
      : AppUser(
          uid: u.uid,
          isGuest: u.isAnonymous,
          email: u.email,
          displayName: u.displayName,
        );

  @override
  Stream<AppUser?> watch() => _auth.userChanges().map(_map);

  @override
  AppUser? get current => _map(_auth.currentUser);

  Future<AuthResult> _guard(Future<User?> Function() run) async {
    try {
      final user = await run();
      return user == null
          ? const Err(AppFailure(FailureCode.unknown))
          : Ok(_map(user)!);
    } on FirebaseAuthException catch (e) {
      return Err(_failure(e));
    } on GoogleSignInException catch (e) {
      return Err(
        e.code == GoogleSignInExceptionCode.canceled
            ? const AppFailure(FailureCode.cancelled)
            : AppFailure(FailureCode.unknown, e.description),
      );
    }
  }

  static AppFailure _failure(FirebaseAuthException e) => AppFailure(
    switch (e.code) {
      'network-request-failed' => FailureCode.network,
      'wrong-password' || 'invalid-credential' => FailureCode.wrongPassword,
      'user-not-found' => FailureCode.userNotFound,
      'email-already-in-use' => FailureCode.emailInUse,
      'weak-password' => FailureCode.weakPassword,
      'invalid-email' => FailureCode.invalidEmail,
      'requires-recent-login' => FailureCode.requiresRecentLogin,
      'credential-already-in-use' => FailureCode.credentialInUse,
      _ => FailureCode.unknown,
    },
    e.code,
  );

  @override
  Future<AuthResult> continueAsGuest() =>
      _guard(() async => (await _auth.signInAnonymously()).user);

  @override
  Future<AuthResult> signInWithGoogle() => _guard(() async {
    final google = GoogleSignIn.instance;
    if (!_googleReady) {
      await google.initialize(serverClientId: _serverClientId);
      _googleReady = true;
    }
    final account = await google.authenticate();
    final credential = GoogleAuthProvider.credential(
      idToken: account.authentication.idToken,
    );
    final user = _auth.currentUser;
    if (user != null && user.isAnonymous) {
      return (await user.linkWithCredential(credential)).user;
    }
    return (await _auth.signInWithCredential(credential)).user;
  });

  @override
  Future<AuthResult> signInWithEmail(String email, String password) => _guard(
    () async => (await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    )).user,
  );

  @override
  Future<AuthResult> registerWithEmail(String email, String password) =>
      _guard(() async {
        final user = _auth.currentUser;
        final User? created;
        if (user != null && user.isAnonymous) {
          final credential = EmailAuthProvider.credential(
            email: email.trim(),
            password: password,
          );
          created = (await user.linkWithCredential(credential)).user;
        } else {
          created = (await _auth.createUserWithEmailAndPassword(
            email: email.trim(),
            password: password,
          )).user;
        }
        await created?.sendEmailVerification();
        return created;
      });

  @override
  Future<Result<void, AppFailure>> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return const Ok(null);
    } on FirebaseAuthException catch (e) {
      return Err(_failure(e));
    }
  }

  @override
  Future<void> signOut() async {
    if (_googleReady) await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  }

  @override
  Future<Result<void, AppFailure>> deleteUser() async {
    try {
      await _auth.currentUser?.delete();
      return const Ok(null);
    } on FirebaseAuthException catch (e) {
      return Err(_failure(e));
    }
  }
}

final authServiceProvider = Provider<AuthService>(
  (ref) => FirebaseAuthService(FirebaseAuth.instance),
);

final authStateProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authServiceProvider).watch(),
);
