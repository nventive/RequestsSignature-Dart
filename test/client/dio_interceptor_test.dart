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
    final clockSkewMilliseconds = 6000; // Clock skew in milliseconds
    final toleranceMilliseconds = 500; // Tolerance in milliseconds

    // Arrange
    final options = RequestsSignatureOptions(
      clientId: 'test_client_id',
      clientSecret: 'test_client_secret',
      headerName: 'X-Signature',
      signaturePattern: '{ClientId}:{Nonce}:{Timestamp}:{SignatureBody}',
      disableAutoRetryOnClockSkew: false,
      clockSkew: Duration(milliseconds: clockSkewMilliseconds),
    );

    // Create a Dio instance with mock adapter
    final dio = Dio(BaseOptions(
      validateStatus: (status) => true,
    ));

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
      request.reply(
        HttpStatus.unauthorized,
        {},
      );
    });

    // Act
    final response = await dio.get('https://google.ca/');

    // Assert
    expect(response.statusCode, HttpStatus.unauthorized);

    // Calculate the expected time difference
    final expectedTimeDiff =
        serverDate.difference(DateTime.now().toUtc()).inMilliseconds;

    // Assert that the time difference equals the clock skew
    expect(expectedTimeDiff.abs(),
        lessThanOrEqualTo(clockSkewMilliseconds + toleranceMilliseconds));
  });
}
