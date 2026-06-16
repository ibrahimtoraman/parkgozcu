import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileRepository {
  ProfileRepository({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
  })  : _auth = auth,
        _firestore = firestore;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<int> watchAppreciationCount(String userId) {
    return _firestore
        .collection('Users')
        .doc(userId)
        .collection('appreciations')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<bool> watchHasGivenAppreciation({
    required String targetUserId,
    required String giverUserId,
  }) {
    return _firestore
        .collection('Users')
        .doc(targetUserId)
        .collection('appreciations')
        .doc(giverUserId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  Future<void> giveAppreciation(String targetUserId) async {
    final giverId = _auth.currentUser?.uid;
    if (giverId == null) {
      throw FirebaseAuthException(
        code: 'unauthenticated',
        message: 'Değer vermek için giriş yapmalısın.',
      );
    }
    if (giverId == targetUserId) {
      throw FirebaseAuthException(
        code: 'invalid-argument',
        message: 'Kendine değer veremezsin.',
      );
    }

    await _firestore
        .collection('Users')
        .doc(targetUserId)
        .collection('appreciations')
        .doc(giverId)
        .set({
      'giverId': giverId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
