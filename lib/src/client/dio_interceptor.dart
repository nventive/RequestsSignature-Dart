import 'package:dio/dio.dart';
import 'package:requests_signature_dart/requests_signature_dart.dart';

import 'dart:convert';
import 'package:requests_signature_dart/src/client/requests_signature_options.dart';

import 'dart:typed_data';

import 'package:uuid/uuid.dart';

/// Interceptor for signing outgoing requests with request signature.
///
/// This interceptor signs the outgoing requests with a request signature
/// before forwarding them to the inner Dio client for processing.
class RequestsSignatureInterceptor extends Interceptor {
  Uuid _uuid = const Uuid();
  final RequestsSignatureOptions _options;
  final ISignatureBodySourceBuilder _signatureBodySourceBuilder;
  final ISignatureBodySigner _signatureBodySigner;
  int _clockSkew = 0;

  /// Constructs a new [RequestsSignatureInterceptor].
  ///
  /// The [options] parameter specifies the signature options.
  ///
  /// Optionally, you can provide custom implementations for
  /// [signatureBodySourceBuilder] and [signatureBodySigner].
  RequestsSignatureInterceptor(
    this._options, {
    ISignatureBodySourceBuilder? signatureBodySourceBuilder,
    ISignatureBodySigner? signatureBodySigner,
  })  : _signatureBodySourceBuilder =
            signatureBodySourceBuilder ?? SignatureBodySourceBuilder(),
        _signatureBodySigner =
            signatureBodySigner ?? HashAlgorithmSignatureBodySigner();

  @override
  Future onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      // Sign the request before it is sent
      await _signRequest(options);
      // Proceed with the request
      return handler.next(options);
    } catch (e) {
      throw RequestsSignatureException(e.toString());
    }
  }

  /// Signs the outgoing request with a request signature.
  Future<void> _signRequest(RequestOptions options) async {
    options.headers
        .remove(_options.headerName); // Remove existing signature header

    final signatureBodySourceComponents =
        _options.signatureBodySourceComponents.isNotEmpty
            ? _options.signatureBodySourceComponents
            : DefaultConstants.signatureBodySourceComponents;

    Uint8List? body;
    // Encode request body if required by signature components
    if (options.data != null &&
        signatureBodySourceComponents
            .contains(SignatureBodySourceComponents.body)) {
      body = utf8.encode(options.data.toString());
    }

    // Build parameters for constructing the signature body
    final signatureBodySourceParameters = SignatureBodySourceParameters(
        options.method,
        options.uri,
        options.headers
            .map((key, value) => MapEntry(key.toString(), value.toString())),
        _uuid.v4(), // Generate a nonce
        _getTimestamp(),
        _options.clientId!,
        signatureBodySourceComponents,
        body: body);

    // Build the signature body source based on parameters
    final signatureBodySource =
        await _signatureBodySourceBuilder.build(signatureBodySourceParameters);

    // Construct parameters for creating the signature
    final signatureBodyParameters =
        SignatureBodyParameters(signatureBodySource, _options.clientSecret!);

    // Generate the signature using the signer
    final signatureBody =
        await _signatureBodySigner.sign(signatureBodyParameters);

    // Format the signature header based on the specified pattern
    final signatureHeader = _options.signaturePattern
        .replaceAll("{ClientId}", _options.clientId!)
        .replaceAll("{Nonce}", signatureBodySourceParameters.nonce)
        .replaceAll(
            "{Timestamp}", signatureBodySourceParameters.timestamp.toString())
        .replaceAll("{SignatureBody}", signatureBody);

    // Add the signature header to the request headers
    options.headers[_options.headerName] = signatureHeader;
  }

  // Get the current timestamp in seconds since epoch
  int _getTime() {
    return DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
  }

  int _getTimestamp() => _getTime() + _clockSkew;
}
