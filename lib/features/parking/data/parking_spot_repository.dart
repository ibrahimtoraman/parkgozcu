import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../domain/parking_spot.dart';

class ParkingSpotRepository {
  ParkingSpotRepository({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
  })  : _auth = auth,
        _firestore = firestore;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final _uuid = const Uuid();

  Stream<List<ParkingSpot>> watchActiveSpots() {
    return _firestore.collection('ParkingSpots').snapshots().map((snapshot) {
      final now = DateTime.now();
      final spots = snapshot.docs
          .map((doc) => ParkingSpot.fromMap(doc.id, doc.data()))
          .where((spot) => spot.expiresAt.isAfter(now))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return spots;
    });
  }

  Future<void> cleanupExpiredSpots() async {
    final snapshot = await _firestore.collection('ParkingSpots').get();
    if (snapshot.docs.isEmpty) return;

    final now = Timestamp.now();
    final batch = _firestore.batch();
    var hasDeletes = false;

    for (final doc in snapshot.docs) {
      final expiresAt = doc.data()['expiresAt'] as Timestamp?;
      if (expiresAt != null && !expiresAt.toDate().isAfter(now.toDate())) {
        batch.delete(doc.reference);
        hasDeletes = true;
      }
    }

    if (hasDeletes) {
      await batch.commit();
    }
  }

  Future<String> createSpot({
    required String userId,
    required String userName,
    required double latitude,
    required double longitude,
    required String address,
  }) async {
    if (_auth.currentUser == null) {
      throw FirebaseAuthException(
        code: 'unauthenticated',
        message: 'Park yeri bildirmek için giriş yapmalısın.',
      );
    }

    final now = DateTime.now();
    final expiresAt = now.add(ParkingSpot.lifetime);
    final batch = _firestore.batch();

    final existing = await _firestore
        .collection('ParkingSpots')
        .where('userId', isEqualTo: userId)
        .get();
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }

    final id = _uuid.v4();
    batch.set(_firestore.collection('ParkingSpots').doc(id), {
      'userId': userId,
      'userName': userName,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'createdAt': Timestamp.fromDate(now),
      'expiresAt': Timestamp.fromDate(expiresAt),
    });

    await batch.commit();
    return id;
  }

  Future<void> deleteSpot(String spotId) async {
    if (_auth.currentUser == null) {
      throw FirebaseAuthException(
        code: 'unauthenticated',
        message: 'Bu işlem için giriş yapmalısın.',
      );
    }

    final doc = await _firestore.collection('ParkingSpots').doc(spotId).get();
    if (!doc.exists) return;

    final ownerId = doc.data()?['userId'] as String? ?? '';
    if (ownerId != _auth.currentUser!.uid) {
      throw FirebaseAuthException(
        code: 'permission-denied',
        message: 'Bu park bildirimini silemezsin.',
      );
    }

    await doc.reference.delete();
  }
}
