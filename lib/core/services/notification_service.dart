import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  NotificationService({FirebaseMessaging? messaging})
      : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  Future<String?> configure() async {
    if (kIsWeb) return null;

    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
      return _messaging.getToken();
    } catch (_) {
      return null;
    }
  }
}
