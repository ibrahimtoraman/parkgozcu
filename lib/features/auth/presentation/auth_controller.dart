import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/services/notification_service.dart';
import '../data/auth_repository.dart';
import '../domain/entities/app_user.dart';

class AuthController extends ChangeNotifier {
  AuthController({
    required AuthRepository repository,
    required NotificationService notificationService,
  })  : _repository = repository,
        _notificationService = notificationService;

  final AuthRepository _repository;
  final NotificationService _notificationService;
  StreamSubscription? _authSubscription;

  AppUser? user;
  bool isLoading = true;
  String? errorMessage;
  bool _isGuestMode = false;

  bool get isGuest => _isGuestMode || user?.id == 'demo-guest';

  Future<void> bootstrap() async {
    unawaited(_notificationService.configure());

    try {
      user = await _repository.currentUserProfile().timeout(
            const Duration(seconds: 3),
            onTimeout: () => null,
          );
    } catch (_) {
      user = null;
    }

    isLoading = false;
    notifyListeners();

    _authSubscription = _repository.authStateChanges().listen((_) async {
      if (_isGuestMode) return;
      try {
        user = await _repository.currentUserProfile();
      } catch (_) {
        user = null;
      }
      isLoading = false;
      notifyListeners();
    });
  }

  Future<void> signInWithGoogle() => _run(_repository.signInWithGoogle);

  Future<void> signInWithApple() => _run(_repository.signInWithApple);

  Future<void> signInAsGuest() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      try {
        await _repository.signOut();
      } catch (_) {}
      _isGuestMode = true;
      user = AppUser(
        id: 'demo-guest',
        name: 'Misafir Kullanıcı',
        email: '',
        photoUrl: '',
        score: 0,
        createdAt: DateTime.now(),
      );
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    if (isGuest) {
      _isGuestMode = false;
      user = null;
      notifyListeners();
      return;
    }
    await _repository.signOut();
  }

  Future<void> _run(Future<AppUser> Function() action) async {
    isLoading = true;
    errorMessage = null;
    _isGuestMode = false;
    notifyListeners();
    try {
      user = await action();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  String _friendlyErrorMessage(Object error) {
    if (error is PlatformException) {
      final message = '${error.code} ${error.message}'.toLowerCase();
      if (message.contains('sign_in_failed') ||
          message.contains('api.exception: 10') ||
          message.contains('apiexception: 10')) {
        return 'Google girişi için Firebase Android SHA-1/SHA-256 ve google-services.json ayarları gerekli.';
      }
    }

    final message = error.toString().toLowerCase();
    if (message.contains('api-key-not-valid')) {
      return 'Firebase API key geçersiz. Firebase ayarlarını tamamlamalısın.';
    }

    return error.toString();
  }
}
