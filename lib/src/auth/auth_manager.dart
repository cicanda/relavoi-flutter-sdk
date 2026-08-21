import '../client/api_client.dart';
import '../relavoi_config.dart';
import '../relavoi_exception.dart';
import '../internal/logger.dart';

class AuthManager {
  final ApiClient _client;
  final RelavoiConfig _config;
  DateTime? _tokenExpiresAt;

  AuthManager(this._client, this._config);

  Future<String> authenticate() async {
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
