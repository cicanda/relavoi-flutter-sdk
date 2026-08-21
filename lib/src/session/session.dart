class Session {
  final String id;
  final String tenantId;
  final String proxyNumber;
  final SessionState state;
  final DirectionMode directionMode;
  final Map<String, dynamic>? metadata;
  final int gracePeriodMinutes;
  final int maxDurationMinutes;
  final bool recordingEnabled;
  final String consentPrompt;
  final DateTime expiresAt;
  final DateTime createdAt;
  final DateTime? activatedAt;
  final DateTime? endedAt;
  final DateTime? expiredAt;
  final int callCount;
  final DateTime? lastCallAt;

  Session({
    required this.id,
    required this.tenantId,
    required this.proxyNumber,
    required this.state,
    required this.directionMode,
    this.metadata,
    required this.gracePeriodMinutes,
    required this.maxDurationMinutes,
    required this.recordingEnabled,
    required this.consentPrompt,
    required this.expiresAt,
    required this.createdAt,
    this.activatedAt,
    this.endedAt,
    this.expiredAt,
    required this.callCount,
    this.lastCallAt,
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json['id'] as String,
      tenantId: json['tenantId'] as String,
      proxyNumber: json['proxyNumber'] as String,
      state: SessionState.fromString(json['state'] as String),
      directionMode: DirectionMode.fromString(json['directionMode'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
      gracePeriodMinutes: json['gracePeriodMinutes'] as int? ?? 15,
      maxDurationMinutes: json['maxDurationMinutes'] as int? ?? 120,
      recordingEnabled: json['recordingEnabled'] as bool? ?? false,
      consentPrompt: json['consentPrompt'] as String? ?? 'NONE',
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      activatedAt: json['activatedAt'] != null
          ? DateTime.parse(json['activatedAt'] as String)
          : null,
      endedAt: json['endedAt'] != null
          ? DateTime.parse(json['endedAt'] as String)
          : null,
      expiredAt: json['expiredAt'] != null
          ? DateTime.parse(json['expiredAt'] as String)
          : null,
      callCount: json['callCount'] as int? ?? 0,
      lastCallAt: json['lastCallAt'] != null
          ? DateTime.parse(json['lastCallAt'] as String)
          : null,
    );
  }
}

enum SessionState {
  pending,
  active,
  gracePeriod,
  expired,
  failed;

  static SessionState fromString(String value) {
    switch (value.toUpperCase()) {
      case 'PENDING':
        return SessionState.pending;
      case 'ACTIVE':
        return SessionState.active;
      case 'GRACE_PERIOD':
        return SessionState.gracePeriod;
      case 'EXPIRED':
        return SessionState.expired;
      case 'FAILED':
        return SessionState.failed;
      default:
        return SessionState.pending;
    }
  }
}

enum DirectionMode {
  bidirectional,
  aToB,
  bToA;

  static DirectionMode fromString(String value) {
    switch (value.toUpperCase()) {
      case 'BIDIRECTIONAL':
        return DirectionMode.bidirectional;
      case 'A_TO_B_ONLY':
        return DirectionMode.aToB;
      case 'B_TO_A_ONLY':
        return DirectionMode.bToA;
      default:
        return DirectionMode.bidirectional;
    }
  }
}

class SessionListResponse {
  final List<Session> data;
  final int count;
  final String? after;

  SessionListResponse({required this.data, required this.count, this.after});

  factory SessionListResponse.fromJson(Map<String, dynamic> json) {
    final dataList = (json['data'] as List?) ?? [];
    return SessionListResponse(
      data: dataList
          .map((e) => Session.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      count: json['pagination']?['count'] as int? ?? dataList.length,
      after: json['pagination']?['after'] as String?,
    );
  }
}
