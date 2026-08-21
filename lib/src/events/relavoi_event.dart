enum EventType {
  sessionCreated,
  sessionExpired,
  callIncoming,
  callAnswered,
  callEnded,
  callFailed,
  smsSent,
  unknown;

  static EventType fromString(String value) {
    switch (value) {
      case 'session.created':
        return EventType.sessionCreated;
      case 'session.expired':
        return EventType.sessionExpired;
      case 'call.incoming':
        return EventType.callIncoming;
      case 'call.answered':
        return EventType.callAnswered;
      case 'call.ended':
        return EventType.callEnded;
      case 'call.failed':
        return EventType.callFailed;
      case 'sms.sent':
        return EventType.smsSent;
      default:
        return EventType.unknown;
    }
  }
}

class RelavoiEvent {
  final EventType type;
  final String rawType;
  final Map<String, dynamic> payload;
  final DateTime timestamp;

  RelavoiEvent({
    required this.type,
    required this.rawType,
    required this.payload,
    required this.timestamp,
  });

  factory RelavoiEvent.fromJson(Map<String, dynamic> json) {
    final rawType = json['type'] as String? ?? '';
    return RelavoiEvent(
      type: EventType.fromString(rawType),
      rawType: rawType,
      payload: Map<String, dynamic>.from(json['payload'] as Map? ?? {}),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }
}
