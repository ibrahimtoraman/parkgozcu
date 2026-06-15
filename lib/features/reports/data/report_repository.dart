import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

import '../domain/entities/report.dart';

class ReportFilters {
  const ReportFilters({this.type, this.days});

  final ReportType? type;
  final int? days;
}

class ReportRepository {
  ReportRepository({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required FirebaseStorage storage,
  })  : _auth = auth,
        _firestore = firestore,
        _storage = storage;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final _uuid = const Uuid();

  Stream<List<ParkingReport>> watchReports(ReportFilters filters) {
    return _firestore
        .collection('Reports')
        .limit(250)
        .snapshots()
        .map((snapshot) {
      var reports = snapshot.docs
          .map((doc) => ParkingReport.fromMap(doc.id, doc.data()))
          .toList();

      if (filters.type != null) {
        reports =
            reports.where((report) => report.type == filters.type).toList();
      }

      if (filters.days != null) {
        final earliestDate =
            DateTime.now().subtract(Duration(days: filters.days!));
        reports = reports
            .where((report) => report.createdAt.isAfter(earliestDate))
            .toList();
      }

      reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return reports;
    });
  }

  Stream<ParkingReport> watchReport(String id) {
    return _firestore.collection('Reports').doc(id).snapshots().map(
          (doc) => ParkingReport.fromMap(doc.id, doc.data()!),
        );
  }

  Future<void> createReport({
    required String userId,
    required String userName,
    required ReportType type,
    required String address,
    required String description,
    required double latitude,
    required double longitude,
    required List<File> images,
  }) async {
    final id = _uuid.v4();
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      throw FirebaseAuthException(
        code: 'unauthenticated',
        message: 'Bildirim oluşturmak için tekrar giriş yapmalısın.',
      );
    }
    final ownerId = firebaseUser.uid;
    final ownerName = firebaseUser.displayName?.trim().isNotEmpty == true
        ? firebaseUser.displayName!.trim()
        : userName;
    final imageUrls = await _uploadReportImages(
      reportId: id,
      images: images,
    );

    final report = ParkingReport(
      id: id,
      userId: ownerId,
      userName: ownerName,
      type: type,
      address: address,
      description: description,
      latitude: latitude,
      longitude: longitude,
      imageUrls: imageUrls,
      verifyCount: 0,
      falseReportCount: 0,
      createdAt: DateTime.now(),
    );

    await _firestore
        .collection('Reports')
        .doc(id)
        .set(report.toMap())
        .timeout(const Duration(seconds: 18));

    unawaited(_incrementUserScore(userId: ownerId, userName: ownerName));
  }

  Future<void> _incrementUserScore({
    required String userId,
    required String userName,
  }) async {
    try {
      await _firestore.collection('Users').doc(userId).set({
        'id': userId,
        'name': userName,
        'score': FieldValue.increment(5),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 8));
    } catch (_) {
      // A profile/score update should not hide an already published report.
    }
  }

  Future<List<String>> _uploadReportImages({
    required String reportId,
    required List<File> images,
  }) async {
    final imageUrls = <String>[];
    for (final image in images) {
      try {
        imageUrls.add(
          await _uploadImage(reportId: reportId, image: image).timeout(
            const Duration(seconds: 20),
          ),
        );
      } catch (_) {
        imageUrls.add(await _imageAsInlineDataUrl(image));
      }
    }

    return imageUrls;
  }

  Future<String> _imageAsInlineDataUrl(File image) async {
    final bytes = await image.readAsBytes();
    return 'data:image/jpeg;base64,${base64Encode(bytes)}';
  }

  Future<void> verifyReport(String reportId, String userId) async {
    final reportRef = _firestore.collection('Reports').doc(reportId);
    final voteRef = _firestore
        .collection('Reports')
        .doc(reportId)
        .collection('verifications')
        .doc(userId);
    final falseVoteRef = _firestore
        .collection('Reports')
        .doc(reportId)
        .collection('falseReports')
        .doc(userId);

    final batch = _firestore.batch();
    final snapshot = await voteRef.get();
    if (snapshot.exists) {
      batch.delete(voteRef);
      batch.update(reportRef, {'verifyCount': FieldValue.increment(-1)});
    } else {
      final falseSnapshot = await falseVoteRef.get();
      if (falseSnapshot.exists) {
        batch.delete(falseVoteRef);
        batch.update(reportRef, {'falseReportCount': FieldValue.increment(-1)});
      }
      batch.set(voteRef, {'createdAt': FieldValue.serverTimestamp()});
      batch.update(reportRef, {'verifyCount': FieldValue.increment(1)});
    }
    await batch.commit();
  }

  Future<void> flagFalseReport(String reportId, String userId) async {
    final reportRef = _firestore.collection('Reports').doc(reportId);
    final voteRef = _firestore
        .collection('Reports')
        .doc(reportId)
        .collection('falseReports')
        .doc(userId);
    final verifyVoteRef = _firestore
        .collection('Reports')
        .doc(reportId)
        .collection('verifications')
        .doc(userId);

    final batch = _firestore.batch();
    final snapshot = await voteRef.get();
    if (snapshot.exists) {
      batch.delete(voteRef);
      batch.update(reportRef, {'falseReportCount': FieldValue.increment(-1)});
    } else {
      final verifySnapshot = await verifyVoteRef.get();
      if (verifySnapshot.exists) {
        batch.delete(verifyVoteRef);
        batch.update(reportRef, {'verifyCount': FieldValue.increment(-1)});
      }
      batch.set(voteRef, {'createdAt': FieldValue.serverTimestamp()});
      batch.update(reportRef, {'falseReportCount': FieldValue.increment(1)});
    }
    await batch.commit();
  }

  Stream<bool> watchUserVerification(String reportId, String userId) {
    return _firestore
        .collection('Reports')
        .doc(reportId)
        .collection('verifications')
        .doc(userId)
        .snapshots()
        .map((snapshot) => snapshot.exists);
  }

  Stream<bool> watchUserFalseReport(String reportId, String userId) {
    return _firestore
        .collection('Reports')
        .doc(reportId)
        .collection('falseReports')
        .doc(userId)
        .snapshots()
        .map((snapshot) => snapshot.exists);
  }

  Future<void> deleteReport(String reportId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'unauthenticated',
        message: 'Bildirim silmek için tekrar giriş yapmalısın.',
      );
    }

    final reportRef = _firestore.collection('Reports').doc(reportId);
    final reportSnapshot =
        await reportRef.get().timeout(const Duration(seconds: 8));
    if (!reportSnapshot.exists) return;

    final reportUserId = reportSnapshot.data()?['userId'] as String?;
    if (reportUserId != user.uid) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Sadece kendi bildirimi silebilirsin.',
      );
    }

    await reportRef.delete().timeout(const Duration(seconds: 12));
    unawaited(_deleteReportStorage(reportId));
  }

  Future<void> _deleteReportStorage(String reportId) async {
    try {
      final folder = _storage.ref('Reports/$reportId');
      final items = await folder.listAll().timeout(const Duration(seconds: 8));
      await Future.wait(items.items.map((item) => item.delete()));
    } catch (_) {
      // Inline photos or Storage rule issues should not block report deletion.
    }
  }

  Stream<int> watchUserReportCount(String userId) {
    return _firestore
        .collection('Reports')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  Stream<List<ParkingReport>> watchUserReports(String userId) {
    return _firestore
        .collection('Reports')
        .where('userId', isEqualTo: userId)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      final reports = snapshot.docs
          .map((doc) => ParkingReport.fromMap(doc.id, doc.data()))
          .toList();
      reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return reports;
    });
  }

  Stream<int> watchVerifiedUserReportCount(String userId) {
    return _firestore
        .collection('Reports')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .where((doc) => (doc.data()['verifyCount'] as int? ?? 0) > 0)
              .length,
        );
  }

  Stream<int> watchFalseFlaggedUserReportCount(String userId) {
    return _firestore
        .collection('Reports')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .where((doc) => (doc.data()['falseReportCount'] as int? ?? 0) > 0)
              .length,
        );
  }

  Future<String> _uploadImage({
    required String reportId,
    required File image,
  }) async {
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4()}.jpg';
    final ref = _storage.ref('Reports/$reportId/$fileName');
    final upload = await ref
        .putFile(
          image,
          SettableMetadata(contentType: 'image/jpeg'),
        )
        .timeout(const Duration(seconds: 10));
    return upload.ref.getDownloadURL().timeout(const Duration(seconds: 10));
  }
}
