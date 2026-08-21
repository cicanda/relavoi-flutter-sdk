import 'dart:io' show Platform;
import 'package:firebase_messaging/firebase_messaging.dart';
import '../client/api_client.dart';
import '../internal/logger.dart';

class PushManager {
  final ApiClient _client;

  PushManager(this._client);

  /// Register the device's push token for receiving call notifications.
  ///
  /// Call this with the user's phone number so the backend knows
  /// which device to send push notifications to for incoming calls.
  ///
  /// ```dart
  /// await Relavoi.instance.push.registerToken('+2348012345678');
  /// ```
  Future<void> registerToken(String userPhone) async {
    try {
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();

      if (token == null) {
        RelavoiLogger.warn('FCM token is null');
        return;
      }

      await _client.post('/devices/token', data: {
        'userPhone': userPhone,
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'token': token,
      });

      RelavoiLogger.info('Push token registered');
    } catch (e) {
      RelavoiLogger.error('Failed to register push token: $e');
    }
  }

  /// Deactivate the push token (e.g., on logout).
  Future<void> deactivateToken() async {
    try {
      await _client.delete('/devices/token');
      RelavoiLogger.info('Push token deactivated');
    } catch (e) {
      RelavoiLogger.error('Failed to deactivate push token: $e');
    }
  }

  /// Listen for incoming push notifications from Relavoi.
  ///
  /// Returns a stream of notification data maps.
  /// Handle these to show the "Your driver is calling" notification.
  Stream<RemoteMessage> get onMessage => FirebaseMessaging.onMessage;
}
