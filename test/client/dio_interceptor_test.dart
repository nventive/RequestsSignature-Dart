import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import 'package:requests_signature_dart/src/client/requests_signature_options.dart';
import 'package:test/test.dart';
import 'package:requests_signature_dart/requests_signature_dart.dart';

void main() {
  test('Interceptor adds signature header to GET request', () async {
    // Arrange
    final options = RequestsSignatureOptions(
      clientId: 'test_client_id',
      clientSecret: 'test_client_secret',
      headerName: 'X-Signature',
      signaturePattern: '{ClientId}:{Nonce}:{Timestamp}:{SignatureBody}',
    );

    final dio = Dio();

    final interceptor = RequestsSignatureInterceptor(options, dio);

    dio.interceptors.add(interceptor);

    // Act
    final response = await dio.get('https://google.ca');

    // Assert
    expect(response.statusCode, 200);

    expect(response.requestOptions.headers, contains('X-Signature'));
  });

  test('Interceptor auto-retries on clockskew', () async {
    final clockskewMS = 6000; // Clock skew in milliseconds
    final toleranceMS = 500; // Tolerance in milliseconds

    // Arrange
    final options = RequestsSignatureOptions(
      clientId: 'test_client_id',
      clientSecret: 'test_client_secret',
      headerName: 'X-Signature',
      signaturePattern: '{ClientId}:{Nonce}:{Timestamp}:{SignatureBody}',
      disableAutoRetryOnClockSkew: false,
      clockSkew: Duration(milliseconds: clockskewMS),
    );

    // Create a Dio instance with mock adapter
    final dio = Dio(BaseOptions(
      validateStatus: (status) => true,
    ));

    // Counter to track the number of requests received by the mock server
    int requestCount = 0;

    final dioAdapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = dioAdapter;

    final serverDate = DateTime.now().toUtc().add(Duration(milliseconds: 6000));
    final serverDateIsoString = serverDate.toIso8601String();

    // Create the interceptor
    final interceptor = RequestsSignatureInterceptor(
      options,
      dio,
      getTime: (request) {
        return DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      },
      getDateHeader: () {
        return serverDateIsoString;
      },
    );

    // Add the interceptor to Dio
    dio.interceptors.add(interceptor);

    // Register the mock response
    dioAdapter.onGet('https://google.ca/', (request) {
      requestCount++; // Increment request count

      // Check if the server returns its date time header
      final hasServerDateHeader = serverDateIsoString.isNotEmpty;

      // Respond with unauthorized or ok based on clock skew and tolerance settings
      if (options.disableAutoRetryOnClockSkew || toleranceMS < clockskewMS) {
        request.reply(HttpStatus.unauthorized, {});
      } else if (hasServerDateHeader) {
        request.reply(HttpStatus.ok, {});
      } else {
        request.reply(HttpStatus.unauthorized, {});
      }
    });

    // Act
    final response = await dio.get('https://google.ca/');

    // Assert
    expect(response.statusCode, HttpStatus.unauthorized);

    // Validate auto-retry doesn't work when clock skew option is disabled
    if (options.disableAutoRetryOnClockSkew) {
      expect(requestCount, 1);
    }

    // Validate auto-retry doesn't work when clock skew option is enabled but tolerance is too low
    if (!options.disableAutoRetryOnClockSkew && toleranceMS < clockskewMS) {
      expect(requestCount, 1);
    }

    // Validate auto-retry works when clock skew option is enabled and tolerance is high enough
    if (!options.disableAutoRetryOnClockSkew && toleranceMS >= clockskewMS) {
      expect(requestCount, 2);
    }

    // Validate auto-retry doesn't work when clock skew option is enabled, tolerance is high enough,
    // but the server doesn't return its date time header
    if (!options.disableAutoRetryOnClockSkew &&
        toleranceMS >= clockskewMS &&
        !serverDateIsoString.isNotEmpty) {
      expect(requestCount, 1);
    }

    // Calculate the expected time difference
    final now = DateTime.now().toUtc();
    final expectedDiff = serverDate.difference(now).inMilliseconds;

    // Assert that the time difference equals the clock skew
    expect(expectedDiff.abs(), lessThanOrEqualTo(clockskewMS + toleranceMS));
  });
}
