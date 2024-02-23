import 'dart:typed_data';

/// Parameters required for constructing a signature body source.
///
/// This class encapsulates the parameters required for constructing a signature body source,
/// including the HTTP method, URI, headers, nonce, timestamp, client ID, components of the signature body source,
/// and optional request body.
class SignatureBodySourceParameters {
  /// The HTTP method of the request.
  final String method;

  /// The URI of the request.
  final Uri uri;

  /// The headers of the request.
  final Map<String, String> headers;

  /// The nonce value for the request.
  final String nonce;

  /// The timestamp of the request.
  final int timestamp;

  /// The client ID associated with the request.
  final String clientId;

  /// The components of the signature body source.
  final List<String> signatureBodySourceComponents;

  /// The optional request body.
  ///
  /// If provided, it should be a list of byte lists.
  final Uint8List? body;

  /// Creates a new [SignatureBodySourceParameters] instance.
  ///
  /// [method] is the HTTP method of the request.
  ///
  /// [uri] is the URI of the request.
  ///
  /// [headers] are the headers of the request.
  ///
  /// [nonce] is the nonce value for the request.
  ///
  /// [timestamp] is the timestamp of the request.
  ///
  /// [clientId] is the client ID associated with the request.
  ///
  /// [signatureBodySourceComponents] are the components of the signature body source.
  ///
  /// [body] is the optional request body, which defaults to an empty list.
  SignatureBodySourceParameters(
    this.method,
    this.uri,
    this.headers,
    this.nonce,
    this.timestamp,
    this.clientId,
    this.signatureBodySourceComponents, {
    this.body,
  });

  /// Returns a string representation of the signature body source parameters.
  ///
  /// This string representation includes the method, URI, nonce, and timestamp.
  @override
  String toString() {
    return '$method $uri $nonce $timestamp';
  }
}
