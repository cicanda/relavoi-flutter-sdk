import '../client/api_client.dart';
import '../relavoi_config.dart';
import '../relavoi_exception.dart';
import '../internal/logger.dart';
import 'token_provider.dart';

class AuthManager {
  final ApiClient _client;
  final RelavoiConfig _config;

  /// Set when the app supplied one. Then the SDK never holds a secret: it
  /// asks the app, the app asks its own backend, and the backend holds it.
  final RelavoiTokenProvider? _tokenProvider;

  DateTime? _tokenExpiresAt;

  AuthManager(this._client, this._config, {RelavoiTokenProvider? tokenProvider})
      : _tokenProvider = tokenProvider;

  Future<String> authenticate() async {
    final provider = _tokenProvider;
    if (provider != null) {
      final token = await provider();
      if (token.accessToken.isEmpty) {
        throw AuthenticationException('Token provider returned an empty accessToken');
      }
      _client.setToken(token.accessToken);
      // The same one minute of headroom the credentials path uses, so a
      // request in flight does not expire mid-call.
      _tokenExpiresAt = DateTime.now()
          .add(Duration(seconds: (token.expiresInSeconds - 60).clamp(0, 86400)));
      RelavoiLogger.info('Took a token from the provider');
      return token.accessToken;
    }

    final response = await _client.postUnauthenticated('/auth/token', {
      'apiKey': _config.apiKey,
      'apiSecret': _config.apiSecret,
    });

    final token = response['accessToken'] as String?;
    if (token == null) throw AuthenticationException('No token in response');

    _client.setToken(token);
    final expiresIn = response['expiresIn'] as int? ?? 900;
    _tokenExpiresAt = DateTime.now().add(Duration(seconds: expiresIn - 60));

    RelavoiLogger.info('Authenticated successfully');
    return token;
  }

  Future<String> ensureValidToken() async {
    if (_tokenExpiresAt == null || DateTime.now().isAfter(_tokenExpiresAt!)) {
      return await authenticate();
    }
    return _client.token!;
  }

  String? get currentToken => _client.token;
}
