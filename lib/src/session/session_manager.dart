import 'package:url_launcher/url_launcher.dart';
import '../client/api_client.dart';
import '../internal/phone_utils.dart';
import '../relavoi_exception.dart';
import '../internal/logger.dart';
import 'session.dart';

class SessionManager {
  final ApiClient _client;

  SessionManager(this._client);

  /// Create a new masking session.
  ///
  /// ```dart
  /// final session = await Relavoi.instance.sessions.create(
  ///   agentPhone: '+2348012345678',
  ///   customerPhone: '+2348087654321',
  ///   metadata: {'orderId': 'ORD-123'},
  /// );
  /// print('Proxy: ${session.proxyNumber}');
  /// ```
  Future<Session> create({
    required String agentPhone,
    required String customerPhone,
    Map<String, dynamic>? metadata,
    int gracePeriodMinutes = 15,
    DirectionMode directionMode = DirectionMode.bidirectional,
    bool recordingEnabled = false,
  }) async {
    PhoneUtils.validateE164(agentPhone);
    PhoneUtils.validateE164(customerPhone);

    final directionString = {
      DirectionMode.bidirectional: 'BIDIRECTIONAL',
      DirectionMode.aToB: 'A_TO_B_ONLY',
      DirectionMode.bToA: 'B_TO_A_ONLY',
    }[directionMode]!;

    final response = await _client.post('/sessions', data: {
      'agentPhone': agentPhone,
      'customerPhone': customerPhone,
      'metadata': metadata ?? {},
      'gracePeriodMinutes': gracePeriodMinutes,
      'directionMode': directionString,
      'recordingEnabled': recordingEnabled,
    });

    final session = Session.fromJson(response);
    RelavoiLogger.info(
        'Session created: ${session.id}, proxy: ${session.proxyNumber}');
    return session;
  }

  /// Get a session by ID.
  Future<Session> get(String sessionId) async {
    final response = await _client.get('/sessions/$sessionId');
    return Session.fromJson(response);
  }

  /// End an active session.
  Future<void> end(String sessionId) async {
    await _client.post('/sessions/$sessionId/end');
    RelavoiLogger.info('Session ended: $sessionId');
  }

  /// List sessions with optional filters.
  Future<SessionListResponse> list({
    SessionState? state,
    int limit = 20,
    String? after,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (state != null) params['state'] = state.name.toUpperCase();
    if (after != null) params['after'] = after;

    final response = await _client.get('/sessions', queryParams: params);
    return SessionListResponse.fromJson(response);
  }

  /// Open the native phone dialer with the session's proxy number.
  ///
  /// The user taps dial in the native dialer to place the call.
  /// The call goes through the regular phone network (PSTN).
  Future<void> initiateCall(String proxyNumber) async {
    PhoneUtils.validateE164(proxyNumber);
    final uri = Uri.parse('tel:$proxyNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      RelavoiLogger.info('Dialer opened with $proxyNumber');
    } else {
      throw RelavoiException('Cannot open phone dialer');
    }
  }
}
