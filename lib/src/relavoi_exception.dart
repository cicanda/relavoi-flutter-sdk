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

class TierLimitException extends RelavoiException {
  TierLimitException(super.message) : super(statusCode: 429);
}
