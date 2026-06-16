import 'package:cloud_firestore/cloud_firestore.dart';

class ParkingSpot {
  const ParkingSpot({
    required this.id,
    required this.userId,
    required this.userName,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.createdAt,
    required this.expiresAt,
  });

  static const lifetime = Duration(minutes: 10);

  final String id;
  final String userId;
  final String userName;
  final double latitude;
  final double longitude;
  final String address;
  final DateTime createdAt;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Duration get remainingTime {
    final remaining = expiresAt.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  factory ParkingSpot.fromMap(String id, Map<String, dynamic> map) {
    return ParkingSpot(
      id: id,
      userId: map['userId'] as String? ?? '',
      userName: map['userName'] as String? ?? 'Kullanıcı',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
      address: map['address'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (map['expiresAt'] as Timestamp?)?.toDate() ??
          DateTime.now().add(lifetime),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
    };
  }
}
