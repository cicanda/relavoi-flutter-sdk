class VerificationResult {
  final bool verified;
  final String? context;
  final String? sessionId;
  final String? proxyNumber;

  VerificationResult({
    required this.verified,
    this.context,
    this.sessionId,
    this.proxyNumber,
  });

  factory VerificationResult.fromJson(Map<String, dynamic> json) {
    return VerificationResult(
      verified: json['verified'] as bool? ?? false,
      context: json['context'] as String?,
      sessionId: json['sessionId'] as String?,
      proxyNumber: json['proxyNumber'] as String?,
    );
  }
}
