import 'dart:convert';
import 'package:test/test.dart';
import 'package:requests_signature_dart/src/core/implementation/signature_body_source_builder.dart';
import 'package:requests_signature_dart/src/core/implementation/signature_body_source_components.dart';
import 'package:requests_signature_dart/src/core/implementation/signature_body_source_parameters.dart';

void main() {
  group('SignatureBodySourceBuilderTests', () {
    Iterable<List<dynamic>> itShouldBuildSourceValueFromComponentsData() sync* {
      const method = 'POST';
      final uri = Uri.parse('https://example.org/api/users?search=foo');
      final headers = {'Header1': 'Value1'};
      const nonce = 'some_nonce';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      const clientId = 'ClientId';
      final body = utf8.encode('FOO');

      yield [
        SignatureBodySourceParameters(
          method,
          uri,
          headers,
          nonce,
          timestamp,
          clientId,
          [],
        ),
        <int>[],
      ];

      yield [
        SignatureBodySourceParameters(
          method,
          uri,
          headers,
          nonce,
          timestamp,
          clientId,
          [SignatureBodySourceComponents.nonce],
        ),
        utf8.encode(nonce),
      ];

      yield [
        SignatureBodySourceParameters(
          method,
          uri,
          headers,
          nonce,
          timestamp,
          clientId,
          [
            SignatureBodySourceComponents.nonce,
            SignatureBodySourceComponents.timestamp,
          ],
        ),
        utf8.encode(nonce) + utf8.encode(timestamp.toString()),
      ];

      yield [
        SignatureBodySourceParameters(
          method,
          uri,
          headers,
          nonce,
          timestamp,
          clientId,
          [
            SignatureBodySourceComponents.method,
            SignatureBodySourceComponents.scheme,
            SignatureBodySourceComponents.host,
            SignatureBodySourceComponents.localPath,
            SignatureBodySourceComponents.queryString,
          ],
        ),
        utf8.encode(method) +
            utf8.encode(uri.scheme) +
            utf8.encode(uri.host) +
            utf8.encode(uri.path) +
            utf8.encode(uri.query),
      ];

      yield [
        SignatureBodySourceParameters(
          method,
          uri,
          headers,
          nonce,
          timestamp,
          clientId,
          [SignatureBodySourceComponents.body],
          body: body,
        ),
        body,
      ];

      yield [
        SignatureBodySourceParameters(
          method,
          uri,
          headers,
          nonce,
          timestamp,
          clientId,
          [SignatureBodySourceComponents.header('Header1')],
        ),
        utf8.encode(headers['Header1']!),
      ];
    }

    itShouldBuildSourceValueFromComponentsData().forEach((data) {
      final parameters = data[0] as SignatureBodySourceParameters;
      final expected = data[1] as List<int>;

      test('ItShouldBuildSourceValueFromComponents', () async {
        final builder = SignatureBodySourceBuilder();
        final result = await builder.build(parameters);
        expect(result, expected);
      });
    });
  });
}
