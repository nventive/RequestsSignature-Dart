import 'package:dio/dio.dart';
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

  test('Interceptor adds signature header to POST request', () async {
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
    final response =
        await dio.post('https://example.com', data: {'key': 'value'});

    // Assert
    expect(response.statusCode, 200);
    expect(response.requestOptions.headers, contains('X-Signature'));
  });

  test('Interceptor handles invalid request URL', () async {
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

    // Act & Assert
    expect(
      () async => await dio.get('invalid_url'), // Request with invalid URL
      throwsA(isA<DioException>()), // Expect DioException due to invalid URL
    );
  });

  test('Interceptor handles malformed request data', () async {
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

    // Act & Assert
    expect(
      () async => await dio.post('https://example.com',
          data: 'invalid_data'), // Request with malformed data
      throwsA(isA<FormatException>()), // FormatException due to malformed data
    );
  });
}
