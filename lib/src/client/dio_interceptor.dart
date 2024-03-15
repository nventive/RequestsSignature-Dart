import 'dart:math';

import 'package:cryptography/dart.dart';
import 'package:dio/dio.dart';
import 'package:requests_signature_dart/requests_signature_dart.dart';

/// Interceptor for signing HTTP requests with HMAC authentication.
///
/// This interceptor adds HMAC authentication headers to outgoing HTTP requests
/// based on the provided client ID and client secret. It calculates the signature
/// using the specified hash algorithm.
class HMACDioInterceptor extends Interceptor {
  /// The client ID used for HMAC authentication.
  final String clientId;

  /// The client secret used for HMAC authentication.
  final String clientSecret;

  /// The signer used to calculate the HMAC signature.
  final HashAlgorithmSignatureBodySigner signer;

  /// Creates a new [HMACInterceptor] instance.
  ///
  /// [clientId] is the client ID used for HMAC authentication.
  ///
  /// [clientSecret] is the client secret used for HMAC authentication.
  HMACDioInterceptor(this.clientId, this.clientSecret)
      : signer =
            HashAlgorithmSignatureBodySigner(hmacAlgorithm: DartHmac.sha256());

  @override
  Future onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    // Generate timestamp and nonce
    final timestamp = _epochTime();
    final nonce = _genGuid();

    // Extract request details
    final uri = options.uri;
    final method = options.method;
    final headers = options.headers;

    // Prepare parameters for signature calculation
    final signatureBodySourceParameters = SignatureBodySourceParameters(
      method,
      uri,
      headers.map((key, value) => MapEntry(key.toString(), value.toString())),
      nonce,
      timestamp,
      clientId,
      DefaultConstants.signatureBodySourceComponents,
    );

    // Build the signature body source
    final bodySourceBuilder = SignatureBodySourceBuilder();
    final signatureBodySource =
        await bodySourceBuilder.build(signatureBodySourceParameters);
    final signatureBodyParameters =
        SignatureBodyParameters(signatureBodySource, clientSecret);

    // Calculate HMAC signature
    final signature = await signer.sign(signatureBodyParameters);

    // Add authentication headers to the request
    options.headers['X-RequestSignature-ClientId'] = clientId;
    options.headers['X-RequestSignature-Nonce'] = nonce;
    options.headers['X-RequestSignature-Timestamp'] = timestamp.toString();
    options.headers['X-RequestSignature-Signature'] = signature;

    return super.onRequest(options, handler);
  }

  /// Generates a random nonce.
  ///
  /// The nonce is a unique string used for each request to prevent replay attacks.
  String _genGuid() {
    const String uuid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx';
    return uuid.replaceAllMapped(RegExp('[xy]'), (match) {
      final int rand = Random().nextInt(16);
      final int index = match.group(0) == 'x' ? rand : (rand & 0x3 | 0x8);
      return index.toRadixString(16);
    });
  }

  /// Returns the current epoch time in milliseconds.
  int _epochTime() {
    return DateTime.now().millisecondsSinceEpoch;
  }
}
