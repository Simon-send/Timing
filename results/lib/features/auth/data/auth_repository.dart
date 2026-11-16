import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

abstract class AuthRepository {
  Stream<User?> authStateChanges();

  User? get currentUser;

  Future<GoogleSignInOutcome> signInWithGoogle();

  Future<User?> completeGoogleRedirect();

  Future<void> signInWithEmail({
    required String email,
    required String password,
  });

  Future<void> createUserWithEmail({
    required String email,
    required String password,
    Future<void> Function(String uid)? onCreated,
  });

  Future<void> sendPasswordResetEmail({required String email});

  Future<void> signOut();
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({FirebaseAuth? auth, this.onGoogleUserCreated})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;
  final Future<void> Function(String uid)? onGoogleUserCreated;

  @override
  User? get currentUser => _auth.currentUser;

  @override
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  @override
  Future<GoogleSignInOutcome> signInWithGoogle() async {
    if (!kIsWeb) {
      throw UnsupportedError('Google login is configured for web first.');
    }
    if (Uri.base.scheme != 'http' && Uri.base.scheme != 'https') {
      throw const AuthWebEnvironmentException();
    }
    final provider = GoogleAuthProvider();
    if (googleSignInMethodFor(defaultTargetPlatform) ==
        GoogleSignInMethod.redirect) {
      await _auth.signInWithRedirect(provider);
      return GoogleSignInOutcome.redirectStarted;
    }
    final credential = await _auth.signInWithPopup(provider);
    if (credential.additionalUserInfo?.isNewUser == true &&
        credential.user != null) {
      await onGoogleUserCreated?.call(credential.user!.uid);
    }
    return GoogleSignInOutcome.signedIn;
  }

  @override
  Future<User?> completeGoogleRedirect() async {
    if (!kIsWeb) return null;
    final credential = await _auth.getRedirectResult();
    if (credential.additionalUserInfo?.isNewUser == true &&
        credential.user != null) {
      await onGoogleUserCreated?.call(credential.user!.uid);
    }
    return credential.user;
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user;
    if (user != null && _requiresEmailVerification(user)) {
      await _auth.signOut();
      throw const EmailNotVerifiedException();
    }
  }

  @override
  Future<void> createUserWithEmail({
    required String email,
    required String password,
    Future<void> Function(String uid)? onCreated,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    Object? consentError;
    try {
      if (credential.user != null) {
        try {
          await onCreated?.call(credential.user!.uid);
        } on Object {
          consentError = const RegistrationConsentSaveException();
        }
      }
      await credential.user?.sendEmailVerification();
      if (consentError != null) throw consentError;
    } finally {
      await _auth.signOut();
    }
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  @override
  Future<void> signOut() => _auth.signOut();
}

enum GoogleSignInOutcome { signedIn, redirectStarted }

enum GoogleSignInMethod { popup, redirect }

GoogleSignInMethod googleSignInMethodFor(TargetPlatform platform) {
  return switch (platform) {
    TargetPlatform.android || TargetPlatform.iOS => GoogleSignInMethod.redirect,
    _ => GoogleSignInMethod.popup,
  };
}

bool _requiresEmailVerification(User user) {
  final usesPassword = user.providerData.any(
    (provider) => provider.providerId == EmailAuthProvider.PROVIDER_ID,
  );
  return usesPassword && !user.emailVerified;
}

class EmailNotVerifiedException implements Exception {
  const EmailNotVerifiedException();

  @override
  String toString() => 'EmailNotVerifiedException';
}

class AuthWebEnvironmentException implements Exception {
  const AuthWebEnvironmentException();

  @override
  String toString() => 'AuthWebEnvironmentException';
}

class RegistrationConsentSaveException implements Exception {
  const RegistrationConsentSaveException();
}
