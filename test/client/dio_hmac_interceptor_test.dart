import 'package:dio/dio.dart';
import 'package:test/test.dart';
import 'package:requests_signature_dart/requests_signature_dart.dart';

void main() {
  group('HMACDioInterceptor', () {
    test('Interceptor signs the request with authentication headers', () async {
      // Arrange
      final dio = Dio();
      final interceptor =
          HMACDioInterceptor("your_client_id", "your_client_secret");
      dio.interceptors.add(interceptor);

      final options = RequestOptions(
        method: 'GET',
        path: '/api/data',
        baseUrl: 'https://example.com',
        headers: {'Content-Type': 'application/json'},
      );

      // Act
      await interceptor.onRequest(options, RequestInterceptorHandler());

      // Assert
      expect(options.headers['X-RequestSignature-ClientId'], "your_client_id");
      expect(options.headers['X-RequestSignature-Nonce'], isNotEmpty);
      expect(options.headers['X-RequestSignature-Timestamp'], isNotEmpty);
      expect(options.headers['X-RequestSignature-Signature'], isNotEmpty);
    });
  });
}
