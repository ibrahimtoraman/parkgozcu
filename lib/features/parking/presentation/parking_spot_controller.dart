import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/parking_spot_repository.dart';
import '../domain/parking_spot.dart';

class ParkingSpotController extends ChangeNotifier {
  ParkingSpotController({required ParkingSpotRepository repository})
      : _repository = repository {
    _spotsSubscription = _repository.watchActiveSpots().listen(
      (spots) {
        activeSpots = spots;
        notifyListeners();
      },
      onError: (Object error) {
        errorMessage = error.toString();
        notifyListeners();
      },
    );
    unawaited(_repository.cleanupExpiredSpots());
    _cleanupTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      unawaited(_repository.cleanupExpiredSpots());
    });
  }

  final ParkingSpotRepository _repository;
  StreamSubscription<List<ParkingSpot>>? _spotsSubscription;
  Timer? _cleanupTimer;

  List<ParkingSpot> activeSpots = const [];
  bool isSubmitting = false;
  String? errorMessage;

  Stream<List<ParkingSpot>> get spots => _repository.watchActiveSpots();

  Future<void> reportAvailableSpot({
    required String userId,
    required String userName,
    required double latitude,
    required double longitude,
    required String address,
  }) async {
    isSubmitting = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _repository.createSpot(
        userId: userId,
        userName: userName,
        latitude: latitude,
        longitude: longitude,
        address: address,
      );
    } catch (error) {
      errorMessage = error.toString();
      rethrow;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> removeSpot(String spotId) async {
    isSubmitting = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _repository.deleteSpot(spotId);
    } catch (error) {
      errorMessage = error.toString();
      rethrow;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _spotsSubscription?.cancel();
    _cleanupTimer?.cancel();
    super.dispose();
  }
}
