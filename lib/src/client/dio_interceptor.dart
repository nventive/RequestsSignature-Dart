import 'dart:async';
import 'dart:developer';
import 'dart:io';

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
  final Dio _dioInstance;
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
    this._options,
    this._dioInstance, {
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
      log('[✓] onRequest triggered');
      await _signRequest(options);

      return handler.next(options);
    } catch (err, stackTrace) {
      log('[x] onrequest error');
      throw RequestsSignatureException('$err\n$stackTrace');
    }
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _validateOptions();

    try {
      log('[✓] Initial response status code : ${response.statusCode} OK');

      if (!_options.disableAutoRetryOnClockSkew &&
          ((response.statusCode == HttpStatus.unauthorized) ||
              (response.statusCode == HttpStatus.forbidden)) &&
          response.headers.value(HttpHeaders.dateHeader) != null) {
        log(response.headers.value(HttpHeaders.dateHeader.toString()) == null
            ? '[!] HttpHeaders.dateHeader NULL'
            : '[✓] HttpHeaders.dateHeader NOT NULL');
        final serverDate =
            int.tryParse(response.headers.value(HttpHeaders.dateHeader)!);
        final now = _getTime(
            DateTime.tryParse(response.headers.value(HttpHeaders.dateHeader)!));

        if (((serverDate! - now).abs()) > _options.clockSkew.inSeconds) {
          log('[✓] onResponse triggered [IF_BLOCK]');
          _clockSkew = serverDate - now;
          // Re-sign the request with the updated clockskew
          _signRequest(response.requestOptions);
          // Resend the request
          _resendRequest(response.requestOptions, handler);

          return handler.next(response);
        }
      }
    } catch (err, stackTrace) {
      log('[x] onResponse error');
      throw RequestsSignatureException('$err\n$stackTrace');
    }
  }

  Future<void> _resendRequest(
      RequestOptions options, ResponseInterceptorHandler handler) async {
    try {
      log('[✓] resendRequest triggered in try..catch block');
      final response = await _dioInstance.fetch(options);
      return handler.next(response);
    } catch (error, stackTrace) {
      log('[x] resendRequest error');
      throw RequestsSignatureException('ResendERR\n$error\n$stackTrace');
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
        _getTimestamp(options.headers.values.contains(HttpHeaders.dateHeader)
            ? options.headers[HttpHeaders.dateHeader]
            : null),
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

  // Returns what the client thinks is the current time.
  int _getTime(DateTime? timestamp) {
    if (timestamp != null) {
      final parsedTimestamp = timestamp.millisecondsSinceEpoch ~/ 1000;
      return int.tryParse(parsedTimestamp.toString()) ??
          DateTime.now().millisecondsSinceEpoch ~/ 1000;
    } else {
      return DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    }
  }

  // Returns the timestamp, accounting for the perceived clock skew.
  int _getTimestamp(DateTime? timestamp) {
    return _getTime(timestamp) + _clockSkew;
  }

  void _validateOptions() {
    if (_options.clientId == null || _options.clientId!.isEmpty) {
      throw RequestsSignatureException(
          'Missing ClientId in RequestsSignatureInterceptor options.');
    }

    if (_options.clientSecret == null || _options.clientSecret!.isEmpty) {
      throw RequestsSignatureException(
          'Missing ClientSecret in RequestsSignatureInterceptor options.');
    }

    if (_options.headerName.isEmpty) {
      throw RequestsSignatureException(
          'Missing HeaderName in RequestsSignatureInterceptor options.');
    }

    if (_options.signaturePattern.isEmpty) {
      throw RequestsSignatureException(
          'Missing SignaturePattern in RequestsSignatureInterceptor options.');
    }
  }
}
