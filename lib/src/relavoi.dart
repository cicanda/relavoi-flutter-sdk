import 'relavoi_config.dart';
import 'client/api_client.dart';
import 'auth/auth_manager.dart';
import 'session/session_manager.dart';
import 'verification/verification_manager.dart';
import 'events/event_manager.dart';
import 'push/push_manager.dart';
import 'presence/presence_manager.dart';
import 'internal/logger.dart';

class Relavoi {
  static Relavoi? _instance;
  static Relavoi get instance {
    assert(_instance != null,
        'Relavoi not initialized. Call Relavoi.initialize() first.');
    return _instance!;
  }

  final RelavoiConfig config;
  late final ApiClient _apiClient;
  late final AuthManager _authManager;
  late final SessionManager sessions;
  late final VerificationManager verification;
  late final EventManager events;
  late final PushManager push;
  late final PresenceManager presence;

  Relavoi._(this.config);

  /// Initialize the Relavoi SDK. Call once at app startup.
  ///
  /// ```dart
  /// await Relavoi.initialize(
  ///   apiKey: 'rk_live_...',
  ///   apiSecret: 'rs_...',
  ///   tenantId: 'your-tenant-uuid',
  /// );
  /// ```
  static Future<void> initialize({
    required String apiKey,
    required String apiSecret,
    required String tenantId,
    RelavoiConfig? config,
  }) async {
    assert(apiKey.isNotEmpty, 'API key must not be empty');
    assert(apiSecret.isNotEmpty, 'API secret must not be empty');
    assert(tenantId.isNotEmpty, 'Tenant ID must not be empty');

    final effectiveConfig = (config ?? const RelavoiConfig()).copyWith(
      apiKey: apiKey,
      apiSecret: apiSecret,
      tenantId: tenantId,
    );

    RelavoiLogger.enabled = effectiveConfig.enableLogging;

    final instance = Relavoi._(effectiveConfig);

    instance._apiClient = ApiClient(effectiveConfig);
    instance._authManager = AuthManager(instance._apiClient, effectiveConfig);

    // Authenticate immediately
    await instance._authManager.authenticate();

    instance.sessions = SessionManager(instance._apiClient);
    instance.verification = VerificationManager(instance._apiClient);
    instance.events = EventManager(effectiveConfig, instance._authManager);
    instance.push = PushManager(instance._apiClient);
    instance.presence = PresenceManager(instance._apiClient);

    _instance = instance;
    RelavoiLogger.info('SDK initialized. Tenant: $tenantId');
  }

  /// Shut down the SDK, close connections.
  static void shutdown() {
    _instance?.events.disconnect();
    _instance?.presence.stop();
    _instance = null;
    RelavoiLogger.info('SDK shut down');
  }

  /// Whether the SDK has been initialized.
  static bool get isInitialized => _instance != null;
}
