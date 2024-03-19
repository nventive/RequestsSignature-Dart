import 'package:dio/dio.dart';
import 'package:requests_signature_dart/requests_signature_dart.dart';

import 'dart:convert';
import 'package:requests_signature_dart/src/client/requests_signature_options.dart';

import 'dart:typed_data';

/// Interceptor for signing outgoing requests with request signature.
///
/// This interceptor signs the outgoing requests with a request signature
/// before forwarding them to the inner Dio client for processing.
class RequestsSignatureInterceptor extends Interceptor {
  final RequestsSignatureOptions _options;
  final ISignatureBodySourceBuilder _signatureBodySourceBuilder;
  final ISignatureBodySigner _signatureBodySigner;

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
        _signatureBodySigner = signatureBodySigner!;

  @override
  Future onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    // Sign the request before it is sent
    await _signRequest(options);
    return handler.next(options); // Proceed with the request
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
        _genGuid(),
        _epochTime(),
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
    final signature = await _signatureBodySigner.sign(signatureBodyParameters);

    // Format the signature header based on the specified pattern
    final signatureHeader = _options.signaturePattern
        .replaceAll("{ClientId}", _options.clientId!)
        .replaceAll("{Nonce}", signatureBodySourceParameters.nonce)
        .replaceAll(
            "{Timestamp}", signatureBodySourceParameters.timestamp.toString())
        .replaceAll("{SignatureBody}", signature);

    // Add the signature header to the request headers
    options.headers[_options.headerName] = signatureHeader;
  }

  // Generate a unique nonce
  String _genGuid() {
    final uuid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx';
    return uuid.replaceAllMapped(RegExp('[xy]'), (match) {
      final rand = DateTime.now().millisecond;
      final index = match.group(0) == 'x' ? rand : (rand & 0x3 | 0x8);
      return index.toRadixString(16);
    });
  }

  // Get the current timestamp in seconds since epoch
  int _epochTime() {
    return DateTime.now().millisecondsSinceEpoch ~/ 1000;
  }
}
