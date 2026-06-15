import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../domain/entities/app_user.dart';

class AuthRepository {
  AuthRepository(
      {required FirebaseAuth auth, required FirebaseFirestore firestore})
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
    return _ensureUserDocument(
      result.user!,
      preferredName: googleUser.displayName?.trim(),
      preferredEmail: googleUser.email.trim(),
    );
  }

  Future<AppUser> signInWithApple() async {
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName
      ],
    );
    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );
    final result = await _auth.signInWithCredential(oauthCredential);

    final givenName = appleCredential.givenName?.trim() ?? '';
    final familyName = appleCredential.familyName?.trim() ?? '';
    final appleName =
        [givenName, familyName].where((part) => part.isNotEmpty).join(' ');
    final appleEmail = appleCredential.email?.trim() ?? '';

    if (appleName.isNotEmpty) {
      await result.user?.updateDisplayName(appleName);
      await result.user?.reload();
    }

    final refreshedUser = _auth.currentUser ?? result.user!;
    return _ensureUserDocument(
      refreshedUser,
      preferredName: appleName.isNotEmpty ? appleName : null,
      preferredEmail: appleEmail.isNotEmpty ? appleEmail : null,
    );
  }

  Future<AppUser> signInAsGuest() async {
    final result = await _auth.signInAnonymously();
    return _ensureUserDocument(result.user!);
  }

  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await _auth.signOut();
  }

  Future<AppUser> _ensureUserDocument(
    User user, {
    String? preferredName,
    String? preferredEmail,
  }) async {
    final resolvedName = _resolveName(
      user: user,
      preferredName: preferredName,
    );
    final resolvedEmail = _resolveEmail(
      user: user,
      preferredEmail: preferredEmail,
    );

    final profile = AppUser(
      id: user.uid,
      name: resolvedName,
      email: resolvedEmail,
      photoUrl: user.photoURL ?? '',
      score: 0,
      createdAt: DateTime.now(),
    );

    try {
      final ref = _firestore.collection('Users').doc(user.uid);
      final snapshot = await ref.get();

      if (snapshot.exists) {
        final existing = AppUser.fromMap(user.uid, snapshot.data()!);
        final mergedName = _pickBetterName(existing.name, resolvedName);
        final mergedEmail = _pickBetterEmail(existing.email, resolvedEmail);

        if (mergedName != existing.name || mergedEmail != existing.email) {
          await ref.update({
            'name': mergedName,
            'email': mergedEmail,
          });
          return existing.copyWith(name: mergedName, email: mergedEmail);
        }

        return existing;
      }

      await ref.set(profile.toMap());
    } on FirebaseException catch (error) {
      if (error.code != 'unavailable') rethrow;
    }

    return profile;
  }

  String _resolveName({
    required User user,
    String? preferredName,
  }) {
    if (preferredName != null && preferredName.trim().isNotEmpty) {
      return preferredName.trim();
    }

    final displayName = user.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    if (user.isAnonymous) {
      return 'Misafir Kullanıcı';
    }

    return 'ParkGözcü Kullanıcı';
  }

  String _resolveEmail({
    required User user,
    String? preferredEmail,
  }) {
    if (preferredEmail != null && preferredEmail.trim().isNotEmpty) {
      return preferredEmail.trim();
    }

    return user.email?.trim() ?? '';
  }

  String _pickBetterName(String existingName, String candidateName) {
    if (_isPlaceholderName(existingName) &&
        !_isPlaceholderName(candidateName)) {
      return candidateName;
    }
    if (existingName.trim().isEmpty && candidateName.trim().isNotEmpty) {
      return candidateName;
    }
    return existingName;
  }

  String _pickBetterEmail(String existingEmail, String candidateEmail) {
    if (existingEmail.trim().isEmpty && candidateEmail.trim().isNotEmpty) {
      return candidateEmail;
    }
    return existingEmail;
  }

  bool _isPlaceholderName(String name) {
    final normalized = name.trim().toLowerCase();
    return normalized.isEmpty ||
        normalized == 'parkgözcü kullanıcı' ||
        normalized == 'parkgozcu kullanici' ||
        normalized == 'misafir kullanıcı';
  }
}
