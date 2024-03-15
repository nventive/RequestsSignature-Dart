import 'dart:convert';
import 'dart:typed_data';

import 'package:requests_signature_dart/src/core/implementation/signature_body_source_components.dart';
import 'package:requests_signature_dart/src/core/implementation/signature_body_source_parameters.dart';
import 'package:requests_signature_dart/src/core/interface/signature_body_source_builder.dart';

/// A class for building the signature body source.
///
/// This class implements the [ISignatureBodySourceBuilder] interface.
/// It provides functionality to build the signature body source based on the provided parameters.
///
/// Example usage:
/// ```dart
/// final builder = SignatureBodySourceBuilder();
/// final parameters = SignatureBodySourceParameters(
///   uri: Uri.parse('https://example.com/path?query=string'),
///   method: 'GET',
///   body: utf8.encode('example body'),
///   timestamp: DateTime.now(),
///   nonce: 'unique_nonce',
///   headers: {'Content-Type': 'application/json'},
///   signatureBodySourceComponents: ['Method', 'Host', 'QueryString', 'Body'],
/// );
/// final signatureBodySource = await builder.build(parameters);
/// print(signatureBodySource);
/// ```
class SignatureBodySourceBuilder implements ISignatureBodySourceBuilder {
  @override
  Future<Uint8List> build(SignatureBodySourceParameters parameters) async {
    final result = <int>[];

    for (var component in parameters.signatureBodySourceComponents) {
      switch (component) {
        case SignatureBodySourceComponents.method:
          result.addAll(utf8.encode(parameters.method.toUpperCase()));
          break;
        case SignatureBodySourceComponents.scheme:
          if (parameters.uri.isAbsolute) {
            result.addAll(utf8.encode(parameters.uri.scheme));
          }
          break;
        case SignatureBodySourceComponents.host:
          if (parameters.uri.isAbsolute) {
            result.addAll(utf8.encode(parameters.uri.host));
          }
          break;
        case SignatureBodySourceComponents.port:
          if (parameters.uri.isAbsolute) {
            result.addAll(utf8.encode(parameters.uri.port.toString()));
          }
          break;
        case SignatureBodySourceComponents.localPath:
          if (parameters.uri.path.isEmpty) {
            result.addAll(utf8.encode('/'));
          } else {
            result.addAll(utf8.encode(parameters.uri.path));
          }
          break;
        case SignatureBodySourceComponents.queryString:
          result.addAll(utf8.encode(parameters.uri.query));
          break;
        case SignatureBodySourceComponents.body:
          // Check if parameters.body is null before adding it
          if (parameters.body != null) {
            result.addAll(parameters.body!);
          } else {
            result.addAll([]);
          }
          break;
        case SignatureBodySourceComponents.timestamp:
          result.addAll(utf8.encode(parameters.timestamp.toString()));
          break;
        case SignatureBodySourceComponents.nonce:
          result.addAll(utf8.encode(parameters.nonce));
          break;
        default:
          if (SignatureBodySourceComponents.isHeader(component, null)) {
            final headerName = SignatureBodySourceComponents.header(component);

            if (parameters.headers.containsKey(headerName)) {
              result.addAll(utf8.encode(parameters.headers[headerName]!));
            }
          }
      }
    }

    return Uint8List.fromList(result);
  }
}
