import 'dart:async';

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
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

  final int Function(RequestOptions request)? _getTime;
  final String Function()? _getDateHeader;

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
    int Function(RequestOptions request)? getTime,
    String Function()? getDateHeader,
  })  : _signatureBodySourceBuilder =
            signatureBodySourceBuilder ?? SignatureBodySourceBuilder(),
        _signatureBodySigner =
            signatureBodySigner ?? HashAlgorithmSignatureBodySigner(),
        _getTime = getTime,
        _getDateHeader = getDateHeader;

  @override
  Future onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    print('[✓] onRequest triggered');
    await _signRequest(options);
    return handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _validateOptions();

    print('[✓] Initial response status code : ${response.statusCode} OK');
    print('[!] ClockSkew ${_options.clockSkew.inSeconds}');

    if (!_options.disableAutoRetryOnClockSkew &&
        ((response.statusCode == HttpStatus.unauthorized) ||
            (response.statusCode == HttpStatus.forbidden)) &&
        (response.headers.value(HttpHeaders.dateHeader) != null || _getDateHeader != null)) {
      final rawHeaderDate = response.headers.value(HttpHeaders.dateHeader) ?? _getDateHeader!();
      print('raw $rawHeaderDate');

      
      final serverDate = DateTime.parse(rawHeaderDate).millisecondsSinceEpoch ~/ 1000;
      print('server $serverDate');
      final now = getTime(response.requestOptions);
      print('now $now');

      if (((serverDate - now).abs()) > _options.clockSkew.inSeconds) {
        print('[✓] onResponse triggered');

        _clockSkew = serverDate - now;
        // Re-sign the request with the updated clockskew
        _signRequest(response.requestOptions);
        // Resend the request
        _resendRequest(response.requestOptions, handler);
      }
    }
    return handler.next(response);
  }

  Future<void> _resendRequest(
      RequestOptions options, ResponseInterceptorHandler handler) async {
    print('[✓] resendRequest triggered');
    final response = await _dioInstance.fetch(options);
    return handler.next(response);
  }

  /// Signs the outgoing request with a request signature.
  Future<void> _signRequest(RequestOptions options) async {
    print('[✓] signRequest triggered');
    options.headers.remove(_options.headerName);

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
        _getTimestamp(options),
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
  int getTime(RequestOptions request) {
    return _getTime != null
        ? _getTime!(request)
        : DateTime.now().millisecondsSinceEpoch ~/ 1000;
  }

  // Returns the timestamp, accounting for the perceived clock skew.
  int _getTimestamp(RequestOptions request) {
    print('[i] clockSkew: $_clockSkew');
    return getTime(request) + _clockSkew;
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
