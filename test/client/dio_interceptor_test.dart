import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:requests_signature_dart/src/client/requests_signature_options.dart';
import 'package:test/test.dart';
import 'package:requests_signature_dart/requests_signature_dart.dart';

class TestSignatureBodySourceBuilder implements ISignatureBodySourceBuilder {
  @override
  Future<Uint8List> build(SignatureBodySourceParameters parameters) async {
    final data = utf8.encode(parameters.toString());
    return Uint8List.fromList(data);
  }
}

class TestSignatureBodySigner implements ISignatureBodySigner {
  @override
  Future<String> sign(SignatureBodyParameters parameters) async {
    return 'test_signature';
  }
}

void main() {
  group('RequestsSignatureInterceptor Tests', () {
    late RequestsSignatureOptions options;
    late RequestsSignatureInterceptor interceptor;
    late RequestOptions requestOptions;

    setUp(() {
      options = RequestsSignatureOptions(
        clientId: 'test_client_id',
        clientSecret: 'test_client_secret',
        signaturePattern: '{ClientId}:{Nonce}:{Timestamp}:{SignatureBody}',
        headerName: 'X-Request-Signature',
        signatureBodySourceComponents: [
          SignatureBodySourceComponents.method,
          SignatureBodySourceComponents.scheme,
          SignatureBodySourceComponents.host,
          SignatureBodySourceComponents.port,
          SignatureBodySourceComponents.localPath,
          SignatureBodySourceComponents.queryString,
          SignatureBodySourceComponents.body,
          SignatureBodySourceComponents.timestamp,
          SignatureBodySourceComponents.nonce,
        ],
      );

      interceptor = RequestsSignatureInterceptor(
        options,
        signatureBodySourceBuilder: TestSignatureBodySourceBuilder(),
        signatureBodySigner: TestSignatureBodySigner(),
      );

      requestOptions = RequestOptions(path: '/test', method: 'GET');
    });

    test('Interceptor signs request properly', () async {
      // Act
      await interceptor.onRequest(requestOptions, RequestInterceptorHandler());

      // Assert
      expect(requestOptions.headers, contains('X-Request-Signature'));
      expect(requestOptions.headers['X-Request-Signature'], isNotNull);
    });

    test('Interceptor generates unique nonce', () async {
      // Act
      await interceptor.onRequest(requestOptions, RequestInterceptorHandler());

      // Assert
      final nonce =
          requestOptions.headers['X-Request-Signature']!.split(':')[1];
      expect(nonce, isNotNull);
      expect(nonce, isNotEmpty);
    });

    test('Interceptor adds timestamp', () async {
      // Act
      await interceptor.onRequest(requestOptions, RequestInterceptorHandler());

      // Assert
      final timestamp =
          requestOptions.headers['X-Request-Signature']!.split(':')[2];
      expect(timestamp, isNotNull);
      expect(timestamp, isNotEmpty);
      expect(int.tryParse(timestamp), isNotNull);
    });
  });
}
