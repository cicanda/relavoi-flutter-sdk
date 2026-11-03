// The app's own backend, which holds the API secret and calls
// POST /v1/auth/sdk-token. Every initialize sample reaches for it.
import 'package:relavoi_flutter/relavoi_flutter.dart';

class _MyBackend {
  Future<RelavoiToken> relavoiToken() async =>
      RelavoiToken(accessToken: 'stub', expiresInSeconds: 900);
}

final myBackend = _MyBackend();
