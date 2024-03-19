/// This file contains unit tests for the [HMACDioInterceptor] class.
///
/// The [HMACDioInterceptor] class is responsible for adding HMAC authentication headers
/// to outgoing HTTP requests based on the provided client ID and client secret. It calculates
/// the signature using the specified hash algorithm.
///
/// The tests in this file ensure that the interceptor behaves correctly under different scenarios
/// and edge cases, verifying that it signs requests with authentication headers correctly.
/// Suggestions for additional test cases are also provided for further coverage.
///
/// To run the tests, use the `dart test` command with the appropriate arguments.
/// Run test via terminal:
/// ```
/// dart test test/client/dio_hmac_interceptor_test.dart
/// ```
/// Ensure that the appropriate dependencies are included in the `pubspec.yaml` file
/// and imported into the test file for the tests to work properly.
///

import 'package:dio/dio.dart';
import 'package:test/test.dart';
import 'package:requests_signature_dart/requests_signature_dart.dart';

void main() {
  group('HMACDioInterceptor', () {
    test('Interceptor signs the request with authentication headers', () async {
      // Test case to ensure that the interceptor signs requests with authentication headers correctly.
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
