import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

abstract class AuthRepository {
  Stream<User?> authStateChanges();

  User? get currentUser;

  Future<void> signInWithGoogle();

  Future<void> signInWithEmail({
    required String email,
    required String password,
  });

  Future<void> createUserWithEmail({
    required String email,
    required String password,
  });

  Future<void> sendPasswordResetEmail({required String email});

  Future<void> signOut();
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  User? get currentUser => _auth.currentUser;

  @override
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  @override
  Future<void> signInWithGoogle() async {
    if (!kIsWeb) {
      throw UnsupportedError('Google login is configured for web first.');
    }
    await _auth.signInWithPopup(GoogleAuthProvider());
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
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    try {
      await credential.user?.sendEmailVerification();
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
