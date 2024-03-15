import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:requests_signature_dart/src/core/implementation/signature_body_parameters.dart';

/// A class for signing message bodies using a hash algorithm.
///
/// This class provides functionality to sign message bodies using a specified hash algorithm.
///
/// Example usage:
/// ```dart
/// final signer = HashAlgorithmSignatureBodySigner();
/// final parameters = SignatureBodyParameters(
///   data: utf8.encode('example data'),
///   clientSecret: 'your_client_secret',
/// );
/// final signature = await signer.sign(parameters);
/// print(signature);
/// ```
class HashAlgorithmSignatureBodySigner {
  /// Function that builds the hash algorithm using provided [SignatureBodyParameters].
  late DartHmac _hashAlgorithm;

  /// Creates a new [HashAlgorithmSignatureBodySigner] instance.
  ///
  /// If [hashAlgorithmBuilder] is provided, it will be used to construct the hash algorithm.
  /// Otherwise, a default hash algorithm builder will be used.
  HashAlgorithmSignatureBodySigner({DartHmac? hmacAlgorithm}) {
    _hashAlgorithm = hmacAlgorithm == null ? DartHmac.sha256() : hmacAlgorithm;
  }

  /// Signs the provided [SignatureBodyParameters] and returns the signature.
  ///
  /// This method asynchronously calculates the signature for the given parameters.
  /// The signature is calculated using the configured hash algorithm.
  Future<String> sign(SignatureBodyParameters parameters) async {
    final hmac = await _hashAlgorithm.calculateMac(parameters.data,
        secretKey: SecretKey(
            Uint8List.fromList(utf8.encode(parameters.clientSecret))));
    return base64.encode(hmac.bytes);
  }
}
