import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../domain/entities/app_user.dart';

class AuthRepository {
  AuthRepository({required FirebaseAuth auth, required FirebaseFirestore firestore})
      : _auth = auth,
        _firestore = firestore;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentFirebaseUser => _auth.currentUser;

  Future<AppUser?> currentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _ensureUserDocument(user);
  }

  Future<AppUser> signInWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      throw Exception('Google girişi iptal edildi.');
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final result = await _auth.signInWithCredential(credential);
    return _ensureUserDocument(result.user!);
  }

  Future<AppUser> signInWithApple() async {
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
    );
    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );
    final result = await _auth.signInWithCredential(oauthCredential);
    return _ensureUserDocument(result.user!);
  }

  Future<AppUser> signInAsGuest() async {
    final result = await _auth.signInAnonymously();
    return _ensureUserDocument(result.user!);
  }

  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await _auth.signOut();
  }

  Future<AppUser> _ensureUserDocument(User user) async {
    final profile = AppUser(
      id: user.uid,
      name: user.displayName?.trim().isNotEmpty == true
          ? user.displayName!
          : user.isAnonymous
              ? 'Misafir Kullanıcı'
              : 'ParkGözcü Kullanıcı',
      email: user.email ?? '',
      photoUrl: user.photoURL ?? '',
      score: 0,
      createdAt: DateTime.now(),
    );

    try {
      final ref = _firestore.collection('Users').doc(user.uid);
      final snapshot = await ref.get();

      if (snapshot.exists) {
        return AppUser.fromMap(user.uid, snapshot.data()!);
      }

      await ref.set(profile.toMap());
    } on FirebaseException catch (error) {
      if (error.code != 'unavailable') rethrow;
    }

    return profile;
  }
}
