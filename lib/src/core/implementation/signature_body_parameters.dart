import 'dart:typed_data';

/// Parameters required for signing message bodies.
///
/// This class encapsulates the data and client secret required for signing message bodies.
class SignatureBodyParameters {
  /// The data to be signed.
  final Uint8List data;

  /// The client secret used for signing.
  final String clientSecret;

  /// Creates a new [SignatureBodyParameters] instance.
  ///
  /// [data] is the data to be signed.
  ///
  /// [clientSecret] is the client secret used for signing.
  SignatureBodyParameters(this.data, this.clientSecret);
}
