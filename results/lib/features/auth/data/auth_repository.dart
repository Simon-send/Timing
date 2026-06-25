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
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  @override
  Future<void> createUserWithEmail({
    required String email,
    required String password,
  }) async {
    await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<void> signOut() => _auth.signOut();
}
