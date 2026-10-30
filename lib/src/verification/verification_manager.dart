import 'package:flutter/services.dart';
import '../client/api_client.dart';
import '../internal/logger.dart';
import '../internal/phone_utils.dart';
import '../relavoi_exception.dart';
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
    final canonical = PhoneUtils.requireNumberShaped(userPhone, 'userPhone');
    try {
      final response = await _client.get('/sessions/verify', queryParams: {
        'userPhone': canonical,
      });
      return VerificationResult.fromJson(response);
    } on RelavoiException catch (e) {
      // The type and the message, never the exception's own toString(). This
      // number travels in a query string, and Dio puts the request URI into its
      // message, so logging the raw error wrote a plaintext phone number to the
      // console. Our own exception messages are built not to carry one.
      RelavoiLogger.error('Verification failed: ${e.runtimeType}: ${e.message}');
      return VerificationResult(verified: false);
    } catch (e) {
      // Anything not ours: the type only. Its message is not ours to trust.
      RelavoiLogger.error('Verification failed: ${e.runtimeType}');
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
