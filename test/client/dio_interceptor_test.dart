import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:dio/dio.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:requests_signature_dart/src/client/requests_signature_options.dart';
import 'package:test/test.dart';
import 'package:requests_signature_dart/requests_signature_dart.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('Requests Signature Interceptor Test', () {
    final testClientId = 'test_client_id';
    final testClientSecret = 'test_client_secret';
    final headerName = 'X-Signature';
    final signaturePattern = '{ClientId}:{Nonce}:{Timestamp}:{SignatureBody}';
    final baseEndpoint = 'https://google.ca/';
    final emptyDataInjection = '{}'; //Injecting empty data as String
    final Uuid _uuid = const Uuid();

    late Dio dio;
    late int clockskew; // in milliseconds

    setUp(() {
      dio = Dio(BaseOptions(
        validateStatus: (status) =>
            true, // We need to set this to avoid unnecessary throwing exception when we expect an error status.
      ));
      // Setting random clockskew so tests aren't always relying on the same value.
      clockskew = Random().nextInt(2000) + 1000;
    });

    tearDown(() {
      dio.close();
    });

    test('Interceptor adds signature header to GET request.', () async {
      // Arrange
      final options = RequestsSignatureOptions(
        clientId: testClientId,
        clientSecret: testClientSecret,
        headerName: headerName,
        signaturePattern: signaturePattern,
      );

      final dioAdapter = DioAdapter(dio: dio);
      dio.httpClientAdapter = dioAdapter;

      final interceptor = RequestsSignatureInterceptor(options, dio);

      dio.interceptors.add(interceptor);

      var mockServer = MockServerValidator(
        headerName,
        clockskew,
        signaturePattern,
      );

      // Register the mock response
      dioAdapter.onGet(
        baseEndpoint,
        (server) {
          var headers = {
            "date": [DateTime.now().toString()]
          };

          server.replyCallbackAsync(
            HttpStatus.ok,
            (request) async {
              var isValid =
                  await mockServer.validateSignature(request, testClientSecret);

              if (isValid) {
                return emptyDataInjection;
              } else {
                // The status code can only be set while defining the mock. Therefore, we're throwing an exception to simulate an unexpected status code.
                throw "The signature is invalid!";
              }
            },
            headers: headers,
          );
        },
      );

      // Act
      final response = await dio.get(baseEndpoint);

      // Assert
      expect(response.statusCode, 200);
      expect(response.requestOptions.headers, contains(headerName));
    });

    var httpStatusCoveredByAutoRetry = [
      HttpStatus.unauthorized,
      HttpStatus.forbidden,
    ];

    var testCases = [
      TestCase(
          isAutoRetryEnabled: true,
          isDateInHeader: true,
          isToleranceHighEnough: false),
      TestCase(
          isAutoRetryEnabled: true,
          isDateInHeader: false,
          isToleranceHighEnough: true),
      TestCase(
          isAutoRetryEnabled: true,
          isDateInHeader: false,
          isToleranceHighEnough: false),
      TestCase(
          isAutoRetryEnabled: false,
          isDateInHeader: true,
          isToleranceHighEnough: true),
      TestCase(
          isAutoRetryEnabled: false,
          isDateInHeader: true,
          isToleranceHighEnough: false),
      TestCase(
          isAutoRetryEnabled: false,
          isDateInHeader: false,
          isToleranceHighEnough: true),
      TestCase(
          isAutoRetryEnabled: false,
          isDateInHeader: false,
          isToleranceHighEnough: false),
    ];

    httpStatusCoveredByAutoRetry.forEach((serverHttpStatus) {
      test(
          "Interceptor should autoretry on $serverHttpStatus received when it's enabled, a date is set in the response header and the tolerence is high enough.",
          () async {
        // Arrange
        final options = RequestsSignatureOptions(
          clientId: testClientId,
          clientSecret: testClientSecret,
          headerName: headerName,
          signaturePattern: signaturePattern,
          disableAutoRetryOnClockSkew: false,
          clockSkew: Duration(milliseconds: clockskew),
        );

        final dioAdapter = DioAdapter(dio: dio);
        dio.httpClientAdapter = dioAdapter;

        // Create the interceptor
        final interceptor = RequestsSignatureInterceptor(
          options,
          dio,
        );

        // Add the interceptor to Dio
        dio.interceptors.add(interceptor);
        var mockServer = MockServerValidator(
          headerName,
          clockskew,
          signaturePattern,
        );

        var callCount = 0;

        // Register the mock response
        dioAdapter.onGet(
          baseEndpoint,
          (server) {
            Map<String, List<String>> headers = {
              "date": [DateTime.now().toString()]
            };

            server.replyCallbackAsync(serverHttpStatus, (request) async {
              callCount++;

              await Future.delayed(Duration(milliseconds: clockskew));

              var isValid =
                  await mockServer.validateSignature(request, _uuid.v4());

              // Workaround to enqueue different mock responses https://github.com/lomsa-dev/http-mock-adapter/issues/145.
              dioAdapter.onGet(
                baseEndpoint,
                (server) {
                  callCount++;
                  Map<String, List<String>> headers = {};

                  server.reply(
                      serverHttpStatus, (request) => emptyDataInjection,
                      headers: headers);
                },
              );

              if (isValid) {
                // The status code can only be set while defining the mock. Therefore, we're throwing an exception to simulate an unexpected status code.
                throw "The signature should not have been validated";
              } else {
                return emptyDataInjection;
              }
            }, headers: headers);
          },
        );

        // Act
        final response = await dio.get(baseEndpoint);

        // Assert
        expect(callCount, 2);
        expect(response.statusCode, serverHttpStatus);
      });

      testCases.forEach((testCase) {
        test(
            'Interceptor should not autoretry on $serverHttpStatus received when isAutoRetryEnabled=${testCase.isAutoRetryEnabled} and isDateInHeader=${testCase.isDateInHeader} and isToleranceHighEnough=${testCase.isToleranceHighEnough}',
            () async {
          // Arrange
          final options = RequestsSignatureOptions(
            clientId: testClientId,
            clientSecret: testClientSecret,
            headerName: headerName,
            signaturePattern: signaturePattern,
            disableAutoRetryOnClockSkew: !testCase.isAutoRetryEnabled,
            clockSkew: Duration(milliseconds: clockskew),
          );

          final dioAdapter = DioAdapter(dio: dio);
          dio.httpClientAdapter = dioAdapter;

          // Create the interceptor
          final interceptor = RequestsSignatureInterceptor(
            options,
            dio,
          );

          // Add the interceptor to Dio
          dio.interceptors.add(interceptor);

          var mockServer = MockServerValidator(
            headerName,
            clockskew,
            signaturePattern,
          );

          var callCount = 0;

          // Register the mock response
          dioAdapter.onGet(
            baseEndpoint,
            (server) {
              Map<String, List<String>> headers = {};
              if (testCase.isDateInHeader) {
                headers["date"] = [DateTime.now().toString()];
              }

              server.replyCallbackAsync(serverHttpStatus, (request) async {
                callCount++;

                if (testCase.isToleranceHighEnough) {
                  await Future.delayed(Duration(milliseconds: clockskew));
                }
                var isValid =
                    await mockServer.validateSignature(request, _uuid.v4());

                if (isValid) {
                  // The status code can only be set while defining the mock. Therefore, we're throwing an exception to simulate an unexpected status code.
                  throw "The signature should not have been validated!";
                } else {
                  return emptyDataInjection;
                }
              }, headers: headers);
            },
          );

          // Act
          final response = await dio.get(baseEndpoint);

          // Assert
          expect(callCount, 1);
          expect(response.statusCode, serverHttpStatus);
        });
      });
    });
  });
}

/// This entity is used to defined possible tests cases to test when auto-retry is not triggered.
class TestCase {
  final bool isAutoRetryEnabled;
  final bool isDateInHeader;
  final bool isToleranceHighEnough;

  const TestCase({
    required this.isAutoRetryEnabled,
    required this.isDateInHeader,
    required this.isToleranceHighEnough,
  });
}

/// This class represents a server to simulates hmac signature validation.
class MockServerValidator {
  final String _headerName;
  final int clockskew;

  late int _signatureItemsCount;

  MockServerValidator(
    this._headerName,
    this.clockskew,
    String signaturePattern,
  ) {
    _signatureItemsCount = signaturePattern.split(":").length;
  }

  Future<bool> validateSignature(RequestOptions options, String secret) async {
    var signature = options.headers[_headerName] as String?;

    if (signature == null || signature.isEmpty) {
      return false;
    }

    var signatureItems = signature.split(":");

    if (signatureItems.length != _signatureItemsCount) {
      return false;
    }

    var timestamp = signatureItems[2];
    var requestTime = int.parse(timestamp);

    var serverTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if ((requestTime - serverTime).abs() > clockskew) {
      return false;
    }

    var expectedToken = signatureItems.removeLast();
    var dataToParse = signatureItems[1] +
        timestamp +
        options.method +
        options.uri.scheme +
        options.uri.host +
        options.uri.path +
        options.uri.query;

    var hmacAlgo = DartHmac.sha256();
    final hmac = await hmacAlgo.calculateMac(
      utf8.encode(dataToParse),
      secretKey: SecretKey(Uint8List.fromList(utf8.encode(secret))),
    );
    var actualToken = base64.encode(hmac.bytes);

    return expectedToken == actualToken;
  }
}
