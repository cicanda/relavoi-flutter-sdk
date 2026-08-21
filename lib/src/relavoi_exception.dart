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

class TierLimitException extends RelavoiException {
  TierLimitException(super.message) : super(statusCode: 429);
}
