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
    print('[TEST] ${response.headers.value(HttpHeaders.dateHeader)}');
    expect(response.requestOptions.headers, contains('X-Signature'));
  });

  test('Interceptor auto-retries on clockskew', () async {
    // Arrange
    final options = RequestsSignatureOptions(
      clientId: 'test_client_id',
      clientSecret: 'test_client_secret',
      headerName: 'X-Signature',
      signaturePattern: '{ClientId}:{Nonce}:{Timestamp}:{SignatureBody}',
      disableAutoRetryOnClockSkew: false,
      clockSkew: Duration(milliseconds: 6000),
    );

    // Create a Dio instance with mock adapter
    final dio = Dio(BaseOptions(
      validateStatus: (status) => true,
    ));

    final dioAdapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = dioAdapter;

    // Create the interceptor
    final interceptor = RequestsSignatureInterceptor(
      options,
      dio,
      getTime: (request) {
        return DateTime.now()
            .toUtc()
            .subtract(Duration(hours: 1))
            .microsecondsSinceEpoch;
      },
      getDateHeader: () {
        return DateTime.now().toUtc().toIso8601String();
      },
    );

    // Add the interceptor to Dio
    dio.interceptors.add(interceptor);

    // Register the mock response
    dioAdapter.onGet('https://google.ca/', (request) {
      print('[TEST] Sending request timestamp: ${DateTime.now()}');

      request.reply(
        HttpStatus.unauthorized,
        {},
      );
      print('[TEST] Request sent at timestamp: ${DateTime.now()}');
    });

    // Act
    final response = await dio.get('https://google.ca/');

    print('[TEST] Response received at timestamp: ${DateTime.now()}');

    // Assert
    expect(response.statusCode, HttpStatus.ok);

    //final expectedTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    //final actualTimestamp = response.data['data']['timestamp'];
    //final difference = (actualTimestamp - expectedTimestamp).abs();
    // print(
    //     '[TEST] Difference between expected and actual timestamps: $difference');
  });
}
