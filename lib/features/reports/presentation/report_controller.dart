import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/services/location_service.dart';
import '../data/report_repository.dart';
import '../domain/entities/report.dart';

class ReportController extends ChangeNotifier {
  ReportController({
    required ReportRepository repository,
    required LocationService locationService,
  })  : _repository = repository,
        _locationService = locationService;

  final ReportRepository _repository;
  final LocationService _locationService;
  StreamSubscription<LatLng>? _locationSubscription;

  LatLng currentPosition = LocationService.fallbackPosition;
  ReportFilters filters = const ReportFilters();
  bool isSubmitting = false;
  String? errorMessage;

  Stream<List<ParkingReport>> get reports => _repository.watchReports(filters);

  Stream<ParkingReport> watchReport(String id) => _repository.watchReport(id);

  Future<void> loadInitialLocation() async {
    currentPosition = await _locationService.currentLatLng();
    notifyListeners();
    await _startLocationUpdates();
  }

  Future<void> refreshCurrentLocation() => loadInitialLocation();

  Future<void> _startLocationUpdates() async {
    if (_locationSubscription != null) return;

    final stream = await _locationService.positionStream();
    if (stream == null) return;

    _locationSubscription = stream.listen((position) {
      currentPosition = position;
      notifyListeners();
    });
  }

  void setTypeFilter(ReportType? type) {
    filters = ReportFilters(type: type, days: filters.days);
    notifyListeners();
  }

  void setDayFilter(int? days) {
    filters = ReportFilters(type: filters.type, days: days);
    notifyListeners();
  }

  Future<void> createReport({
    required String userId,
    required String userName,
    required ReportType type,
    required String address,
    required String description,
    required LatLng position,
    required List<File> images,
  }) async {
    isSubmitting = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _repository.createReport(
        userId: userId,
        userName: userName,
        type: type,
        address: address,
        description: description,
        latitude: position.latitude,
        longitude: position.longitude,
        images: images,
      );
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      rethrow;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> verifyReport(String reportId, String userId) {
    return _repository.verifyReport(reportId, userId);
  }

  Future<void> flagFalseReport(String reportId, String userId) {
    return _repository.flagFalseReport(reportId, userId);
  }

  Stream<bool> watchUserVerification(String reportId, String userId) {
    return _repository.watchUserVerification(reportId, userId);
  }

  Stream<bool> watchUserFalseReport(String reportId, String userId) {
    return _repository.watchUserFalseReport(reportId, userId);
  }

  Future<void> deleteReport(String reportId) {
    return _repository.deleteReport(reportId);
  }

  Stream<int> watchUserReportCount(String userId) {
    return _repository.watchUserReportCount(userId);
  }

  Stream<List<ParkingReport>> watchUserReports(String userId) {
    return _repository.watchUserReports(userId);
  }

  Stream<int> watchVerifiedUserReportCount(String userId) {
    return _repository.watchVerifiedUserReportCount(userId);
  }

  Stream<int> watchFalseFlaggedUserReportCount(String userId) {
    return _repository.watchFalseFlaggedUserReportCount(userId);
  }

  String _friendlyErrorMessage(Object error) {
    if (error is TimeoutException) {
      return 'Firebase yanıt vermedi. İnternet bağlantını ve Firebase Firestore kurallarını kontrol edip tekrar dene.';
    }

    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' =>
          'Firebase izinleri bildirim oluşturmayı engelliyor. Firestore/Storage kurallarını yayınlamalısın.',
        'unauthenticated' =>
          'Bildirim oluşturmak için tekrar giriş yapmalısın.',
        'object-not-found' =>
          'Fotoğraf yüklenemedi. Firebase Storage ayarlarını kontrol etmelisin.',
        'upload-failed' =>
          'Fotoğraf yüklenemedi. Firebase Storage kurallarını yayınlayıp tekrar dene.',
        'unauthorized' =>
          'Fotoğraf yükleme izni yok. Firebase Storage kurallarını kontrol etmelisin.',
        'unavailable' =>
          'Firebase geçici olarak yanıt vermiyor. Biraz sonra tekrar dene.',
        _ => 'Firebase hatası: ${error.message ?? error.code}',
      };
    }

    return 'Bildirim oluşturulamadı: $error';
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }
}
