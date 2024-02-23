import 'package:requests_signature_dart/src/core/implementation/signature_body_parameters.dart';

/// Computes signature for requests.
abstract class ISignatureBodySigner {
  /// Creates a signature.
  ///
  /// [parameters]: The [SignatureBodyParameters].
  ///
  /// Returns the created signature.
  Future<String> sign(SignatureBodyParameters parameters);
}
