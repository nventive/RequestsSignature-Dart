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

    final interceptor = RequestsSignatureInterceptor(options);

    final dio = Dio();
    dio.interceptors.add(interceptor);

    // Act
    final response = await dio.get('https://google.ca');

    // Assert
    expect(response.statusCode, 200);
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
        clockSkew: Duration(milliseconds: 3000));

    // Create a Dio instance with mock adapter
    final dio = Dio();
    final dioAdapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = dioAdapter;

    // Create the interceptor
    final interceptor = RequestsSignatureInterceptor(options);

    // Add the interceptor to Dio
    dio.interceptors.add(interceptor);

    // Register the mock response
    dioAdapter.onGet('https://example.com/api/test', (request) {
      print('Sending request at timestamp: ${DateTime.now()}');
      request.reply(HttpStatus.ok, {
        'status': 'success',
        'data': {
          'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        },
      });
      print('Request sent at timestamp: ${DateTime.now()}');
    });

    // Act
    final response = await dio.get('https://example.com/api/test');
    print('Response received at timestamp: ${DateTime.now()}');

    // Assert
    expect(response.statusCode, HttpStatus.ok);
    expect(response.data['data'], isNotNull);
    expect(response.data, isMap);

    expect(response.data['data']['timestamp'], isNotNull);
    final expectedTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final actualTimestamp = response.data['data']['timestamp'];
    final difference = (actualTimestamp - expectedTimestamp).abs();
    print('Difference between expected and actual timestamps: $difference');
  });
}
