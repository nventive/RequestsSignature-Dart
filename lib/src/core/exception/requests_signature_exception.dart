class RequestsSignatureException implements Exception {
  final String message;

  RequestsSignatureException(this.message);

  @override
  String toString() => 'RequestsSignatureException: $message';
}
