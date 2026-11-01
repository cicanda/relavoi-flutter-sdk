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
  }) async {
    final agent = PhoneUtils.requireNumberShaped(agentPhone, 'agentPhone');
    final customer =
        PhoneUtils.requireNumberShaped(customerPhone, 'customerPhone');

    final directionString = {
      DirectionMode.bidirectional: 'BIDIRECTIONAL',
      DirectionMode.aToB: 'A_TO_B_ONLY',
      DirectionMode.bToA: 'B_TO_A_ONLY',
    }[directionMode]!;

    final response = await _client.post('/sessions', data: {
      'agentPhone': agent,
      'customerPhone': customer,
      'metadata': metadata ?? {},
      'gracePeriodMinutes': gracePeriodMinutes,
      'directionMode': directionString,
    });

    final session = Session.fromJson(response);
    // The session id only. The proxy number was logged here in plaintext, and
    // the id is the key that actually correlates lines.
    RelavoiLogger.info('Session created: ${session.id}');
    return session;
  }

  /// Get a session by ID.
  Future<Session> get(String sessionId) async {
    final response = await _client.get('/sessions/$sessionId');
    return Session.fromJson(response);
  }

  /// Swap the customer (party B) on an active session.
  ///
  /// The proxy number does not change, so the agent keeps dialling the same
  /// number and each call connects to whoever the current target is. Use this
  /// for sequential calls instead of creating a session per recipient: ten
  /// sessions means ten numbers and ten cooldowns, which exhausts a small pool
  /// partway through a round.
  ///
  /// The previous customer can no longer reach the proxy after a swap.
  ///
  /// ```dart
  /// // Courier has three drops
  /// final session = await Relavoi.instance.sessions.create(
  ///   agentPhone: courierPhone,
  ///   customerPhone: customers[0].phone,
  /// );
  ///
  /// await Relavoi.instance.sessions.initiateCall(session.proxyNumber);
  ///
  /// // Move to the next drop, same proxy number
  /// await Relavoi.instance.sessions.swapTarget(
  ///   session.id,
  ///   customerPhone: customers[1].phone,
  /// );
  ///
  /// await Relavoi.instance.sessions.initiateCall(session.proxyNumber);
  /// ```
  ///
  /// Throws if [customerPhone] is not number-shaped, matches the agent's own number,
  /// or already participates in another live session on the same proxy.
  /// Swapping to the current target is a no-op and returns the session as-is.
  Future<Session> swapTarget(String sessionId,
      {required String customerPhone}) async {
    final customer =
        PhoneUtils.requireNumberShaped(customerPhone, 'customerPhone');
    final response = await _client.patch('/sessions/$sessionId/target', data: {
      'customerPhone': customer,
    });
    RelavoiLogger.info('Session target swapped: $sessionId');
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
    final canonical =
        PhoneUtils.requireNumberShaped(proxyNumber, 'proxyNumber');
    final uri = Uri.parse('tel:$canonical');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      // Not the number: this line used to print it in full.
      RelavoiLogger.info('Dialer opened');
    } else {
      throw RelavoiException('Cannot open phone dialer');
    }
  }
}
