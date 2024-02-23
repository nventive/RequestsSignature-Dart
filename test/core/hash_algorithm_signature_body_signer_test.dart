import 'dart:convert';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:requests_signature_dart/src/core/implementation/hash_algorithm_signature_body_signer.dart';
import 'package:requests_signature_dart/src/core/implementation/signature_body_parameters.dart';

void main() {
  group('HashAlgorithmSignatureBodySignerTests', () {
    test('ItShouldSign', () async {
      final parameters =
          SignatureBodyParameters(Uint8List.fromList([]), 'clientSecret');
      final signer = HashAlgorithmSignatureBodySigner();

      final result = await signer.sign(parameters);
      expect(result.isNotEmpty, true);

      final bytes = base64.decode(result);
      expect(bytes.length, 32);
    });
  });
}
