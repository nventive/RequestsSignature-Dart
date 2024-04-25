/// Exceptions thrown during Requests Signature processing.
class RequestsSignatureException implements Exception {
  /// Message to display when this exception is raised.
  final String message;

  /// Constructs a new [RequestsSignatureException] with a given [message].
  RequestsSignatureException(this.message);

  @override
  String toString() => 'RequestsSignatureException: $message';
}
