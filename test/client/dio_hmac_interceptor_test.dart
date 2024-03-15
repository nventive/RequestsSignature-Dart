import 'package:dio/dio.dart';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:requests_signature_dart/requests_signature_dart.dart';

class MockDio extends Mock implements Dio {}

void main() {
  group('HMACDioInterceptor', () {
    test('Interceptor adds authentication headers correctly', () async {
      // Arrange
      final dio = MockDio();
      final clientId = "your_client_id";
      final clientSecret = "your_client_secret";
      final interceptor = HMACDioInterceptor(clientId, clientSecret);

      final options = RequestOptions(
        method: 'GET',
        path: '/api/data',
        baseUrl: 'https://example.com',
        headers: {'Content-Type': 'application/json'},
      );

      when(dio.request(options.baseUrl, options: anyNamed('options')))
          .thenAnswer((_) async =>
              Response(data: '', statusCode: 200, requestOptions: options));

      // Act
      await interceptor.onRequest(options, RequestInterceptorHandler());

      // Assert
      expect(options.headers['X-RequestSignature-ClientId'], clientId);
      expect(options.headers['X-RequestSignature-Nonce'], isNotEmpty);
      expect(options.headers['X-RequestSignature-Timestamp'], isNotEmpty);
      expect(options.headers['X-RequestSignature-Signature'], isNotEmpty);
    });
  });
}
