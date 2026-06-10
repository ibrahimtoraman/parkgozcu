import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

enum ReportType {
  parkingFine,
  towedVehicle,
  noParking,
  heavyInspection;

  String get label {
    return switch (this) {
      ReportType.parkingFine => 'Park Cezası',
      ReportType.towedVehicle => 'Araç Çekildi',
      ReportType.noParking => 'Park Yasağı',
      ReportType.heavyInspection => 'Yoğun Denetim',
    };
  }

  IconData get icon {
    return switch (this) {
      ReportType.parkingFine => Icons.receipt_long,
      ReportType.towedVehicle => Icons.local_shipping,
      ReportType.noParking => Icons.block,
      ReportType.heavyInspection => Icons.visibility,
    };
  }

  Color get color {
    return switch (this) {
      ReportType.parkingFine => AppColors.red,
      ReportType.towedVehicle => AppColors.darkGrey,
      ReportType.noParking => Colors.orange,
      ReportType.heavyInspection => Colors.deepPurple,
    };
  }

  double get markerHue {
    return switch (this) {
      ReportType.parkingFine => 45,
      ReportType.towedVehicle => 210,
      ReportType.noParking => 0,
      ReportType.heavyInspection => 270,
    };
  }
}

class ParkingReport {
  const ParkingReport({
    required this.id,
    required this.userId,
    required this.userName,
    required this.type,
    required this.address,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.imageUrls,
    required this.verifyCount,
    required this.falseReportCount,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String userName;
  final ReportType type;
  final String address;
  final String description;
  final double latitude;
  final double longitude;
  final List<String> imageUrls;
  final int verifyCount;
  final int falseReportCount;
  final DateTime createdAt;

  factory ParkingReport.fromMap(String id, Map<String, dynamic> map) {
    return ParkingReport(
      id: id,
      userId: map['userId'] as String? ?? '',
      userName: map['userName'] as String? ?? 'Kullanıcı',
      type: ReportType.values.firstWhere(
        (type) => type.name == map['type'],
        orElse: () => ReportType.parkingFine,
      ),
      address: map['address'] as String? ?? '',
      description: map['description'] as String? ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
      imageUrls: List<String>.from(map['imageUrls'] as List? ?? const []),
      verifyCount: map['verifyCount'] as int? ?? 0,
      falseReportCount: map['falseReportCount'] as int? ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'type': type.name,
      'address': address,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'imageUrls': imageUrls,
      'verifyCount': verifyCount,
      'falseReportCount': falseReportCount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
