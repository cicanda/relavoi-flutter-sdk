class RelavoiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic originalError;
  RelavoiException(this.message, {this.statusCode, this.originalError});
  @override
  String toString() => 'RelavoiException: $message';
}

class AuthenticationException extends RelavoiException {
  AuthenticationException(super.message) : super(statusCode: 401);
}

class SessionException extends RelavoiException {
  SessionException(super.message, {super.statusCode});
}

class NetworkException extends RelavoiException {
  NetworkException(super.message, {super.originalError});
}

class ValidationException extends RelavoiException {
  ValidationException(super.message) : super(statusCode: 422);
}

/// The API refused a phone number because Relavoi does not currently connect
/// numbers of that kind. Today that means anything other than a Nigerian mobile
/// number.
///
/// This is a server decision, not a client one: the supported countries live in
/// the platform's countries table and can change without a new SDK release, so
/// do not try to pre-empt it with a local check. [message] never contains the
/// number that was refused.
class NumberNotSupportedException extends RelavoiException {
  NumberNotSupportedException(super.message) : super(statusCode: 422);
}

/// The API refused the session because the two numbers are not in the same
/// country. Cross-border masking is a separate product and is not enabled.
/// [message] never contains either number.
class CrossBorderNotSupportedException extends RelavoiException {
  CrossBorderNotSupportedException(super.message) : super(statusCode: 422);
}

/// The workspace is holding every proxy number its plan allows it to hold at
/// once, and each of them is already in a live session with one of the two
/// people in this request.
///
/// **Do not retry this on a timer.** It is not a rate limit, which is why it is
/// a type of its own rather than [TierLimitException]: no interval makes it
/// clear. It clears when one of the workspace's sessions ends, or when a
/// request for more numbers is approved, which is a change of state. The API
/// sends no Retry-After with it.
///
/// A proxy number carries many sessions at once but never the same person
/// twice, so this is the point at which another number is genuinely needed. If
/// an app hits this often, the workspace should ask for a higher limit from the
/// Numbers page in its dashboard.
///
/// [message] never contains either number.
class NumberQuotaReachedException extends RelavoiException {
  NumberQuotaReachedException(super.message) : super(statusCode: 409);
}

class TierLimitException extends RelavoiException {
  TierLimitException(super.message) : super(statusCode: 429);
}
