import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../domain/parking_spot.dart';

const _googleMapsApiKey = 'AIzaSyCg81cHh7wkLFHQUQizINpovwjP7PcQ2Kw';

class ParkingSpotPreview {
  const ParkingSpotPreview({
    required this.imageUrl,
    required this.isStreetView,
  });

  final String imageUrl;
  final bool isStreetView;
}

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
    final id = _uuid.v4();

    await _firestore.collection('ParkingSpots').doc(id).set({
      'userId': userId,
      'userName': userName,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'createdAt': Timestamp.fromDate(now),
      'expiresAt': Timestamp.fromDate(expiresAt),
    });

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

Future<bool> openParkingSpotStreetView({
  required double latitude,
  required double longitude,
}) async {
  final uri = Uri.parse(
    'https://www.google.com/maps/@?api=1&map_action=pano&viewpoint=$latitude,$longitude',
  );
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<bool> openParkingSpotDirections({
  required double latitude,
  required double longitude,
}) async {
  final uri = Uri.parse(
    'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=driving',
  );
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

String parkingSpotStreetViewStaticUrl({
  required double latitude,
  required double longitude,
  String? panoId,
  int width = 640,
  int height = 480,
}) {
  final locationParam = panoId != null && panoId.isNotEmpty
      ? 'pano=$panoId'
      : 'location=$latitude,$longitude';
  return 'https://maps.googleapis.com/maps/api/streetview'
      '?size=${width}x$height'
      '&$locationParam'
      '&fov=90'
      '&heading=210'
      '&pitch=5'
      '&source=outdoor'
      '&key=$_googleMapsApiKey';
}

String parkingSpotMapPreviewUrl({
  required double latitude,
  required double longitude,
  int width = 640,
  int height = 480,
}) {
  return 'https://maps.googleapis.com/maps/api/staticmap'
      '?center=$latitude,$longitude'
      '&zoom=18'
      '&size=${width}x$height'
      '&maptype=satellite'
      '&markers=color:0x16A34A%7C$latitude,$longitude'
      '&key=$_googleMapsApiKey';
}

Future<ParkingSpotPreview> resolveParkingSpotPreview({
  required double latitude,
  required double longitude,
}) async {
  try {
    final metaUri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/streetview/metadata',
      {
        'location': '$latitude,$longitude',
        'key': _googleMapsApiKey,
        'source': 'outdoor',
      },
    );
    final response = await http.get(metaUri).timeout(const Duration(seconds: 8));
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['status'] == 'OK') {
        final location = body['location'] as Map<String, dynamic>?;
        final panoLat = (location?['lat'] as num?)?.toDouble() ?? latitude;
        final panoLng = (location?['lng'] as num?)?.toDouble() ?? longitude;
        final panoId = body['pano_id'] as String?;

        return ParkingSpotPreview(
          imageUrl: parkingSpotStreetViewStaticUrl(
            latitude: panoLat,
            longitude: panoLng,
            panoId: panoId,
          ),
          isStreetView: true,
        );
      }
    }
  } catch (_) {}

  return ParkingSpotPreview(
    imageUrl: parkingSpotMapPreviewUrl(
      latitude: latitude,
      longitude: longitude,
    ),
    isStreetView: false,
  );
}

String parkingSpotStreetViewEmbedUrl({
  required double latitude,
  required double longitude,
}) {
  return 'https://www.google.com/maps/embed/v1/streetview'
      '?key=$_googleMapsApiKey'
      '&location=$latitude,$longitude'
      '&heading=210&pitch=5&fov=90';
}

String parkingSpotStreetViewEmbedHtml({
  required double latitude,
  required double longitude,
}) {
  final embedUrl = parkingSpotStreetViewEmbedUrl(
    latitude: latitude,
    longitude: longitude,
  );

  return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    html, body {
      margin: 0;
      padding: 0;
      width: 100%;
      height: 100%;
      overflow: hidden;
      background: #e8e8e8;
    }
    iframe {
      border: 0;
      width: 100%;
      height: 100%;
    }
  </style>
</head>
<body>
  <iframe
    allowfullscreen
    loading="lazy"
    referrerpolicy="no-referrer-when-downgrade"
    src="$embedUrl">
  </iframe>
</body>
</html>
''';
}
