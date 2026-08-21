import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../relavoi_config.dart';
import '../auth/auth_manager.dart';
import '../internal/logger.dart';
import 'relavoi_event.dart';
import 'event_listener.dart';

class EventManager {
  final RelavoiConfig _config;
  final AuthManager _authManager;
  WebSocketChannel? _channel;
  bool _isConnected = false;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;

  final _listeners = <EventType, List<EventCallback>>{};
  final _anyListeners = <AnyEventCallback>[];

  EventManager(this._config, this._authManager);

  /// Connect to the real-time event stream.
  ///
  /// Events are delivered as the call progresses:
  /// incoming, answered, ended, session expired, SMS sent, etc.
  ///
  /// ```dart
  /// Relavoi.instance.events.on(EventType.callIncoming, (event) {
  ///   print('Incoming call on session ${event.payload['sessionId']}');
  /// });
  /// Relavoi.instance.events.connect();
  /// ```
  Future<void> connect() async {
    if (_isConnected) return;

    final token = await _authManager.ensureValidToken();
    final wsUrl = '${_config.wsUrl}?token=$token';

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _isConnected = true;
      _reconnectAttempts = 0;
      RelavoiLogger.info('WebSocket connected');

      _channel!.stream.listen(
        (message) {
          try {
            final json = jsonDecode(message as String);
            final event =
                RelavoiEvent.fromJson(Map<String, dynamic>.from(json));
            _dispatch(event);
          } catch (e) {
            RelavoiLogger.error('Failed to parse WebSocket message: $e');
          }
        },
        onDone: () {
          _isConnected = false;
          RelavoiLogger.info('WebSocket closed');
          _attemptReconnect();
        },
        onError: (error) {
          _isConnected = false;
          RelavoiLogger.error('WebSocket error: $error');
          _attemptReconnect();
        },
      );
    } catch (e) {
      RelavoiLogger.error('WebSocket connection failed: $e');
      _attemptReconnect();
    }
  }

  /// Disconnect from the event stream.
  void disconnect() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    RelavoiLogger.info('WebSocket disconnected');
  }

  bool get isConnected => _isConnected;

  /// Listen for a specific event type.
  void on(EventType type, EventCallback callback) {
    _listeners.putIfAbsent(type, () => []).add(callback);
  }

  /// Listen for all events.
  void onAny(AnyEventCallback callback) {
    _anyListeners.add(callback);
  }

  /// Remove all listeners.
  void removeAllListeners() {
    _listeners.clear();
    _anyListeners.clear();
  }

  void _dispatch(RelavoiEvent event) {
    _listeners[event.type]?.forEach((cb) => cb(event));
    for (final cb in _anyListeners) {
      cb(event);
    }
  }

  void _attemptReconnect() {
    if (!_config.autoReconnectWebSocket) return;
    if (_reconnectAttempts >= _config.maxWebSocketReconnectAttempts) {
      RelavoiLogger.error('Max WebSocket reconnect attempts reached');
      return;
    }

    _reconnectAttempts++;
    final delay =
        Duration(seconds: (1 << (_reconnectAttempts - 1)).clamp(1, 60));
    RelavoiLogger.info(
        'WebSocket reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts)');

    _reconnectTimer = Timer(delay, () => connect());
  }
}
