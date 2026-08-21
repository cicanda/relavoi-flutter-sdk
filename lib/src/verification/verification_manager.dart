import 'package:flutter/services.dart';
import '../client/api_client.dart';
import '../internal/logger.dart';
import 'verification_result.dart';

class VerificationManager {
  final ApiClient _client;
  static const _channel = MethodChannel('com.relavoi/call_state');

  VerificationManager(this._client);

  /// Check if an active call is verified (from the platform).
  ///
  /// Call this when the app comes to the foreground during an active call.
  /// Returns verified=true if the current call matches an active masking session.
  ///
  /// ```dart
  /// final result = await Relavoi.instance.verification.verify('+2348012345678');
  /// if (result.verified) {
  ///   showBanner('Your driver is calling', color: Colors.green);
  /// }
  /// ```
  Future<VerificationResult> verify(String userPhone) async {
    try {
      final response = await _client.get('/sessions/verify', queryParams: {
        'userPhone': userPhone,
      });
      return VerificationResult.fromJson(response);
    } catch (e) {
      RelavoiLogger.error('Verification failed: $e');
      return VerificationResult(verified: false);
    }
  }

  /// Check if a phone call is currently active on the device.
  ///
  /// Uses native TelephonyManager (Android) or CXCallObserver (iOS).
  /// Returns false if the native plugin is not available or permission is not granted.
  Future<bool> isCallActive() async {
    try {
      final result = await _channel.invokeMethod<bool>('isCallActive');
      return result ?? false;
    } on MissingPluginException {
      RelavoiLogger.warn('Native call detection not available');
      return false;
    } catch (e) {
      RelavoiLogger.error('Call detection error: $e');
      return false;
    }
  }

  /// Check if READ_PHONE_STATE permission is granted (Android only).
  /// Returns true on iOS (no permission needed for CXCallObserver).
  Future<bool> hasPhoneStatePermission() async {
    try {
      final result =
          await _channel.invokeMethod<bool>('hasPhoneStatePermission');
      return result ?? true;
    } on MissingPluginException {
      return true;
    }
  }

  /// Check if overlay (floating bubble) permission is granted (Android only).
  /// Returns true on iOS (not applicable).
  Future<bool> hasOverlayPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasOverlayPermission');
      return result ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Request overlay permission (opens system settings on Android).
  /// No-op on iOS.
  Future<void> requestOverlayPermission() async {
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } on MissingPluginException {
      // iOS - no overlay permission needed
    }
  }
}
