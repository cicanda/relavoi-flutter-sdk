import 'relavoi_config.dart';
import 'client/api_client.dart';
import 'auth/auth_manager.dart';
import 'auth/token_provider.dart';
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

  /// Initialize the SDK. Call once at app startup.
  ///
  /// Supply a [tokenProvider]: your app asks your own backend for a token, the
  /// backend holds the API secret and calls `POST /v1/auth/sdk-token`, and the
  /// secret never reaches the handset. That matters because anything compiled
  /// into a published app can be read back out of it, and a live key and
  /// secret let anyone create sessions billed to you and list every session
  /// and call on your workspace.
  ///
  /// ```dart
  /// await Relavoi.initialize(
  ///   tenantId: 'your-tenant-uuid',
  ///   tokenProvider: () async => myBackend.relavoiToken(),
  /// );
  /// ```
  ///
  /// [apiKey] and [apiSecret] are the old form. They still work, so existing
  /// integrations keep running, but they are deprecated and should only be
  /// used with a **sandbox** key while you are developing. Dart has no
  /// overloading, so they live here as optional parameters rather than in a
  /// second method: that way no call site has to change before it is ready to.
  ///
  /// Exactly one of the two forms must be supplied.
  static Future<void> initialize({
    required String tenantId,
    RelavoiTokenProvider? tokenProvider,
    @Deprecated('Ship a tokenProvider instead. A secret compiled into an app can be read back out of it.')
    String? apiKey,
    @Deprecated('Ship a tokenProvider instead. A secret compiled into an app can be read back out of it.')
    String? apiSecret,
    RelavoiConfig? config,
  }) async {
    assert(tenantId.isNotEmpty, 'Tenant ID must not be empty');

    final hasCredentials = (apiKey?.isNotEmpty ?? false) && (apiSecret?.isNotEmpty ?? false);
    if (tokenProvider == null && !hasCredentials) {
      throw ArgumentError(
        'Relavoi.initialize needs either a tokenProvider, or an apiKey and '
        'apiSecret. The tokenProvider form is the one to ship.',
      );
    }
    if (tokenProvider != null && hasCredentials) {
      throw ArgumentError(
        'Relavoi.initialize was given both a tokenProvider and an apiKey. '
        'Pick one; the tokenProvider form is the one to ship.',
      );
    }

    // A sandbox key in a shipped app is a nuisance; a live one is a credential
    // anybody with the bundle can take. Say so at runtime, because a
    // deprecation notice is easy to silence.
    if (apiKey != null && apiKey.startsWith('rk_live_')) {
      RelavoiLogger.warn(
        'Relavoi: a LIVE API secret is compiled into this app. It can be '
        'extracted from the bundle, and it can create sessions billed to you '
        'and read every session on your workspace. Move to the tokenProvider '
        'form of initialize().',
      );
    }

    await _start(
      tenantId: tenantId,
      config: config,
      apiKey: apiKey,
      apiSecret: apiSecret,
      tokenProvider: tokenProvider,
    );
  }

  /// The half both initializers share.
  static Future<void> _start({
    required String tenantId,
    RelavoiConfig? config,
    String? apiKey,
    String? apiSecret,
    RelavoiTokenProvider? tokenProvider,
  }) async {
    final effectiveConfig = (config ?? const RelavoiConfig()).copyWith(
      apiKey: apiKey,
      apiSecret: apiSecret,
      tenantId: tenantId,
    );

    RelavoiLogger.enabled = effectiveConfig.enableLogging;

    final instance = Relavoi._(effectiveConfig);

    instance._apiClient = ApiClient(effectiveConfig);
    instance._authManager = AuthManager(
      instance._apiClient,
      effectiveConfig,
      tokenProvider: tokenProvider,
    );

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
