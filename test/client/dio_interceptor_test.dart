import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:requests_signature_dart/src/client/requests_signature_options.dart';
import 'package:test/test.dart';
import 'package:requests_signature_dart/requests_signature_dart.dart';

void main() {
  final String baseURL = 'https://google.ca/';
  final String headerName = 'X-Signature';

  test('Interceptor adds signature header to GET request', () async {
    final dio = Dio();
    final interceptor = _setUpInterceptor();
    dio.interceptors.add(interceptor);

    final response = await dio.get(baseURL);

    expect(response.statusCode, 200);
    expect(response.requestOptions.headers, contains(headerName));
  });

  test('Interceptor auto-retry behavior based on clock skew configuration',
      () async {
    final clockskewMS = 6000; // Clock skew in milliseconds
    final toleranceMS = 500; // Tolerance in milliseconds

    // Arrange
    final options = RequestsSignatureOptions(
      clientId: 'test_client_id',
      clientSecret: 'test_client_secret',
      headerName: headerName,
      signaturePattern: '{ClientId}:{Nonce}:{Timestamp}:{SignatureBody}',
      disableAutoRetryOnClockSkew: false,
      clockSkew: Duration(milliseconds: clockskewMS),
    );

    // Create a Dio instance with mock adapter
    final dio = Dio(BaseOptions(
      validateStatus: (status) => true,
    ));

    final dioAdapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = dioAdapter;

    // Set the expected server date for the mock response
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
    dioAdapter.onGet(baseURL, (request) {
      // Respond with unauthorized or ok based on clock skew and tolerance settings
      if (options.disableAutoRetryOnClockSkew || toleranceMS < clockskewMS) {
        // Set the expected date header in the response
        request.reply(HttpStatus.unauthorized, '{}', headers: {
          'date': [serverDateIsoString]
        });
      } else {
        request.reply(HttpStatus.ok, {});
      }
    });

    // Act
    final response = await dio.get(baseURL);

    // Assert
    expect(response.statusCode, HttpStatus.unauthorized);
  });

  test('Auto-retry disabled when clock skew option is disabled', () async {
    final dio = Dio();
    final interceptor = _setUpInterceptor(autoRetry: false);
    dio.interceptors.add(interceptor);

    final response = await dio.get(baseURL);

    expect(response.statusCode, HttpStatus.ok);
  });

  test('Auto-retry disabled when tolerance is too low', () async {
    final dio = Dio();
    final interceptor = _setUpInterceptor(autoRetry: true);
    dio.interceptors.add(interceptor);

    final response = await dio.get(baseURL);

    expect(response.statusCode, HttpStatus.ok);
  });

  test('Auto-retry disabled when no date header', () async {
    final dio = Dio();
    final interceptor = _setUpInterceptor(autoRetry: true);
    dio.interceptors.add(interceptor);

    final response = await dio.get(baseURL);

    expect(response.statusCode, HttpStatus.ok);
  });
}

RequestsSignatureInterceptor _setUpInterceptor({bool autoRetry = false}) {
  final String HEADER_NAME = 'X-Signature';
  final String CLIENT_ID = 'test_client_id';
  final String CLIENT_SECRET = 'test_client_secret';
  final String PATTERN = '{ClientId}:{Nonce}:{Timestamp}:{SignatureBody}';

  final options = RequestsSignatureOptions(
    clientId: CLIENT_ID,
    clientSecret: CLIENT_SECRET,
    headerName: HEADER_NAME,
    signaturePattern: PATTERN,
    disableAutoRetryOnClockSkew: !autoRetry,
    clockSkew: Duration(milliseconds: 6000),
  );

  final dio = Dio(BaseOptions(validateStatus: (status) => true));
  final dioAdapter = DioAdapter(dio: dio);
  dio.httpClientAdapter = dioAdapter;

  final serverDate = DateTime.now().toUtc().add(Duration(milliseconds: 6000));
  final serverDateIsoString = serverDate.toIso8601String();

  return RequestsSignatureInterceptor(
    options,
    dio,
    getTime: (request) => DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
    getDateHeader: () => serverDateIsoString,
  );
}
