import 'dart:async';
import 'dart:developer';
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
      print('[✓] onRequest triggered');
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
      print('[✓] Initial response status code : ${response.statusCode} OK');
      print('[!] ClockSkew ${_options.clockSkew.inSeconds}');

      if (!_options.disableAutoRetryOnClockSkew &&
          ((response.statusCode == HttpStatus.unauthorized) ||
              (response.statusCode == HttpStatus.forbidden)) &&
          response.headers.value(HttpHeaders.dateHeader) != null) {
        final rawHeaderDate = response.headers.value(HttpHeaders.dateHeader)!;
        final serverDate =
            parseDateString(rawHeaderDate).millisecondsSinceEpoch ~/ 1000;
        final now = getTime(parseDateString(rawHeaderDate));

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
    } catch (err, stackTrace) {
      print('[x] onResponse error');
      throw RequestsSignatureException('$err\n$stackTrace');
    }
  }

  Future<void> _resendRequest(
      RequestOptions options, ResponseInterceptorHandler handler) async {
    try {
      print('[✓] resendRequest triggered');
      final response = await _dioInstance.fetch(options);
      return handler.next(response);
    } catch (error, stackTrace) {
      print('[x] resendRequest error');
      throw RequestsSignatureException('ResendERR\n$error\n$stackTrace');
    }
  }

  /// Signs the outgoing request with a request signature.
  Future<void> _signRequest(RequestOptions options) async {
    print('[i] _signRequest called');
    try {
      print('[✓] _signRequest triggered');
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
      print('[i] _signReq Header: ${options.headers[HttpHeaders.dateHeader]}');

      // Build parameters for constructing the signature body
      final signatureBodySourceParameters = SignatureBodySourceParameters(
          options.method,
          options.uri,
          options.headers
              .map((key, value) => MapEntry(key.toString(), value.toString())),
          _uuid.v4(), // Generate a nonce
          _getTimestamp(options.headers[HttpHeaders.dateHeader]),
          _options.clientId!,
          signatureBodySourceComponents,
          body: body);

      // Build the signature body source based on parameters
      final signatureBodySource = await _signatureBodySourceBuilder
          .build(signatureBodySourceParameters);

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

      print('[DEBUG] Generated Signature Header: $signatureHeader');

      // Add the signature header to the request headers
      options.headers[_options.headerName] = signatureHeader;
    } catch (error, stackTrace) {
      print('[x] _signRequest error');
      throw RequestsSignatureException('$error\n$stackTrace');
    }
  }

  // Returns what the client thinks is the current time.
  static int getTime(DateTime? timestamp) {
    if (timestamp != null && timestamp.toString().isNotEmpty) {
      print('[i] _getTime called with timestamp: $timestamp');

      return timestamp.toUtc().millisecondsSinceEpoch ~/ 1000;
    } else {
      return DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    }
  }

  // Returns the timestamp, accounting for the perceived clock skew.
  int _getTimestamp(DateTime? timestamp) {
    print('[i] clockSkew: $_clockSkew');
    return getTime(timestamp) + _clockSkew;
  }

  // Parses unexpected date strings formats into a DateTime object.
  DateTime parseDateString(String dateString) {
    List<String> possibleFormats = [
      'E, d MMM yyyy HH:mm:ss zzz', // Standard HttpsHeaders.dateHeader format
      'EEE, dd MMM yyyy HH:mm:ss zzz', // Alternative format with full day name
      'EEEE, dd MMMM yyyy HH:mm:ss zzz' // Full day and month names format
    ];

    for (String formatString in possibleFormats) {
      try {
        DateFormat format = DateFormat(formatString);
        return format.parse(dateString);
      } catch (e) {
        // If parsing fails, try the next format
        continue;
      }
    }

    // If no format matches, throw an error or return null
    throw FormatException('Unable to parse date string: $dateString');
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
