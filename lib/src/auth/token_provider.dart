/// A token your own backend minted, handed to the SDK.
///
/// The SDK caches it until shortly before [expiresInSeconds] elapses and then
/// asks for another, so a provider that is cheap to call stays cheap.
class RelavoiToken {
  /// The `accessToken` from `POST /v1/auth/sdk-token`.
  final String accessToken;

  /// Seconds from now, as returned by that endpoint.
  final int expiresInSeconds;

  const RelavoiToken({
    required this.accessToken,
    required this.expiresInSeconds,
  });
}

/// How the SDK asks your app for a token.
///
/// Your app calls your backend, which holds the API secret and calls
/// `POST /v1/auth/sdk-token`. The secret never reaches the handset, which is
/// the point: anything compiled into a published app can be read back out of
/// it.
///
/// ```dart
/// await Relavoi.initialize(
///   tenantId: 'your-tenant-uuid',
///   tokenProvider: () async => myBackend.relavoiToken(),
/// );
/// ```
///
/// Called on first use, shortly before the current token expires, and once
/// after a 401. A throw surfaces to the caller rather than being retried in a
/// loop: a failing provider usually means the user is signed out of your app.
typedef RelavoiTokenProvider = Future<RelavoiToken> Function();
