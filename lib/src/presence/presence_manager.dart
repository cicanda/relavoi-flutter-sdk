import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/widgets.dart';
import '../client/api_client.dart';
import '../internal/logger.dart';

class PresenceManager with WidgetsBindingObserver {
  final ApiClient _client;
  String? _userPhone;
  Timer? _heartbeatTimer;
  String _currentStatus = 'offline';

  PresenceManager(this._client);

  /// Start presence tracking for a user.
  ///
  /// The SDK automatically reports online/background/offline status
  /// based on the app's lifecycle. Call this once after initialization.
  ///
  /// ```dart
  /// Relavoi.instance.presence.start('+2348012345678');
  /// ```
  void start(String userPhone) {
    _userPhone = userPhone;
    WidgetsBinding.instance.addObserver(this);
    _reportStatus('online');
    _startHeartbeat();
    RelavoiLogger.info('Presence tracking started');
  }

  /// Stop presence tracking.
  void stop() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeatTimer?.cancel();
    _reportStatus('offline');
    _userPhone = null;
    RelavoiLogger.info('Presence tracking stopped');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _reportStatus('online');
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _reportStatus('background');
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _reportStatus('offline');
        break;
    }
  }

  void _reportStatus(String status) {
    if (_userPhone == null) return;
    _currentStatus = status;
    _client.post('/devices/presence', data: {
      'userPhone': _userPhone,
      'status': status,
      'platform': Platform.isAndroid ? 'android' : 'ios',
    }).catchError((e) {
      RelavoiLogger.error('Presence update failed: $e');
      return <String, dynamic>{};
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _reportStatus(_currentStatus);
    });
  }
}
