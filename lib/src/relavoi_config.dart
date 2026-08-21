class RelavoiConfig {
  final String apiKey;
  final String apiSecret;
  final String tenantId;
  final String baseUrl;
  final String wsUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final bool enableLogging;
  final Duration presenceHeartbeatInterval;
  final bool autoReconnectWebSocket;
  final int maxWebSocketReconnectAttempts;

  const RelavoiConfig({
    this.apiKey = '',
    this.apiSecret = '',
    this.tenantId = '',
    this.baseUrl = 'https://api.relavoi.com/v1',
    this.wsUrl = 'wss://api.relavoi.com/ws',
    this.connectTimeout = const Duration(seconds: 30),
    this.receiveTimeout = const Duration(seconds: 30),
    this.enableLogging = false,
    this.presenceHeartbeatInterval = const Duration(seconds: 60),
    this.autoReconnectWebSocket = true,
    this.maxWebSocketReconnectAttempts = 10,
  });

  RelavoiConfig copyWith({
    String? apiKey,
    String? apiSecret,
    String? tenantId,
    String? baseUrl,
    String? wsUrl,
    bool? enableLogging,
  }) {
    return RelavoiConfig(
      apiKey: apiKey ?? this.apiKey,
      apiSecret: apiSecret ?? this.apiSecret,
      tenantId: tenantId ?? this.tenantId,
      baseUrl: baseUrl ?? this.baseUrl,
      wsUrl: wsUrl ?? this.wsUrl,
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
      enableLogging: enableLogging ?? this.enableLogging,
      presenceHeartbeatInterval: presenceHeartbeatInterval,
      autoReconnectWebSocket: autoReconnectWebSocket,
      maxWebSocketReconnectAttempts: maxWebSocketReconnectAttempts,
    );
  }
}
