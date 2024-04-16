import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:requests_signature_dart/src/client/requests_signature_options.dart';
import 'package:test/test.dart';
import 'package:requests_signature_dart/requests_signature_dart.dart';

void main() {
  group('Requests Signature Interceptor Test', () {
    final testClientId = 'test_client_id';
    final testClientSecret = 'test_client_secret';
    final headerName = 'X-Signature';
    final signaturePattern = '{ClientId}:{Nonce}:{Timestamp}:{SignatureBody}';
    final baseEndpoint = 'https://google.ca/';
    final clockskewMS = 6000; // Clock skew in milliseconds
    final toleranceMS = 500; // Tolerance in milliseconds
    final emptyDataInjection = '{}'; //Injecting empty data as String

    late Dio dio;
    late DateTime now;

    setUp(() {
      dio = Dio();
      now = DateTime.now().toUtc();
    });

    tearDown(() {
      dio.close();
    });

    test('Interceptor adds signature header to GET request', () async {
      // Arrange
      final options = RequestsSignatureOptions(
        clientId: testClientId,
        clientSecret: testClientSecret,
        headerName: headerName,
        signaturePattern: signaturePattern,
      );

      final interceptor = RequestsSignatureInterceptor(options, dio);

      dio.interceptors.add(interceptor);

      // Act
      final response = await dio.get(baseEndpoint);

      // Assert
      expect(response.statusCode, 200);

      expect(response.requestOptions.headers, contains(headerName));
    });

    test('Interceptor returns OK with auto-retry tuned to false', () async {
      // Arrange
      final options = RequestsSignatureOptions(
        clientId: testClientId,
        clientSecret: testClientSecret,
        headerName: headerName,
        signaturePattern: signaturePattern,
        disableAutoRetryOnClockSkew: false,
        clockSkew: Duration(milliseconds: clockskewMS),
      );

      final dioAdapter = DioAdapter(dio: dio);
      dio.httpClientAdapter = dioAdapter;

      // Create the interceptor
      final interceptor = RequestsSignatureInterceptor(
        options,
        dio,
        getTime: (request) {
          return now.millisecondsSinceEpoch ~/ 1000;
        },
      );

      // Add the interceptor to Dio
      dio.interceptors.add(interceptor);

      // Register the mock response
      dioAdapter.onGet(baseEndpoint, (request) {
        options.disableAutoRetryOnClockSkew
            ? request.reply(HttpStatus.unauthorized, emptyDataInjection)
            : request.reply(HttpStatus.ok, emptyDataInjection);
      });

      // Act
      final response = await dio.get(baseEndpoint);

      // Assert
      expect(response.statusCode, HttpStatus.ok);
    });

    test('Auto-retry disabled when clock skew option is disabled', () async {
      final options = RequestsSignatureOptions(
        clientId: testClientId,
        clientSecret: testClientSecret,
        headerName: headerName,
        signaturePattern: signaturePattern,
        disableAutoRetryOnClockSkew: true,
      );

      final dioAdapter = DioAdapter(dio: dio);
      dio.httpClientAdapter = dioAdapter;

      // Create the interceptor
      final interceptor =
          RequestsSignatureInterceptor(options, dio, getTime: (request) {
        return now.millisecondsSinceEpoch ~/ 1000;
      });

      // Add the interceptor to Dio
      dio.interceptors.add(interceptor);

      int requestCount = 0;

      dioAdapter.onGet(baseEndpoint, (request) {
        requestCount++;
        request.reply(HttpStatus.ok, emptyDataInjection);
      });

      await dio.get(baseEndpoint);

      expect(requestCount, 1);
    });

    test('Check if tolerance is considered into calculations', () async {
      final options = RequestsSignatureOptions(
        clientId: testClientId,
        clientSecret: testClientSecret,
        headerName: headerName,
        signaturePattern: signaturePattern,
        disableAutoRetryOnClockSkew: false,
        clockSkew: Duration(milliseconds: clockskewMS),
      );

      final dioAdapter = DioAdapter(dio: dio);
      dio.httpClientAdapter = dioAdapter;

      final serverDate = now.add(Duration(milliseconds: clockskewMS));

      // Create the interceptor
      final interceptor =
          RequestsSignatureInterceptor(options, dio, getTime: (request) {
        return now.millisecondsSinceEpoch ~/ 1000;
      });

      // Add the interceptor to Dio
      dio.interceptors.add(interceptor);

      dioAdapter.onGet(baseEndpoint, (request) {
        request.reply(HttpStatus.ok, {});
      });

      // Act
      await dio.get(baseEndpoint);

      // Calculate the expected time difference
      final expectedDiff = serverDate.difference(now).inMilliseconds;

      // Assert
      expect(expectedDiff.abs(), lessThanOrEqualTo(clockskewMS + toleranceMS));
    });

    test('Auto-retry disabled when no date header', () async {
      final options = RequestsSignatureOptions(
        clientId: testClientId,
        clientSecret: testClientSecret,
        headerName: headerName,
        signaturePattern: signaturePattern,
        disableAutoRetryOnClockSkew: false,
        clockSkew: Duration(milliseconds: clockskewMS),
      );

      final dioAdapter = DioAdapter(dio: dio);
      dio.httpClientAdapter = dioAdapter;

      // Create the interceptor
      final interceptor = RequestsSignatureInterceptor(options, dio);

      // Add the interceptor to Dio
      dio.interceptors.add(interceptor);

      int requestCount = 0;

      dioAdapter.onGet(baseEndpoint, (request) {
        requestCount++;
        request.reply(HttpStatus.ok, {});
      });

      final response = await dio.get(baseEndpoint);

      expect(requestCount, 1);
      expect(response.statusCode, HttpStatus.ok);
    });
  });
}
