import 'package:requests_signature_dart/src/core/default_constants.dart';
import 'package:requests_signature_dart/src/core/implementation/hash_algorithm_signature_body_signer.dart';
import 'package:requests_signature_dart/src/core/implementation/signature_body_parameters.dart';
import 'package:requests_signature_dart/src/core/implementation/signature_body_source_builder.dart';
import 'package:requests_signature_dart/src/core/implementation/signature_body_source_parameters.dart';
import 'package:test/test.dart';

void main() {
  group('Signature Test', () {
    test('Signature generation comparison test', () async {
      var signer = HashAlgorithmSignatureBodySigner();

      var signatureBodySourceParameters = SignatureBodySourceParameters(
        "GET", //Method
        Uri.parse("https://www.google.ca/"), //Uri
        {}, //Headers
        '0', //Nonce
        0, //Timestamp
        "ClientId", //ClientId
        DefaultConstants.signatureBodySourceComponents, //Components
      );

      var bodySourceBuilder = SignatureBodySourceBuilder();
      var signatureBodySource =
          await bodySourceBuilder.build(signatureBodySourceParameters);
      var signatureBodyParameters =
          SignatureBodyParameters(signatureBodySource, "ClientSecret");

      var signature = await signer.sign(signatureBodyParameters);
      final expectedSignature = '/YtFmf7Sn39rCpOc9GZA4fPQ/WMx5NPDseVPb6Qszv8=';

      expect(signature, equals(expectedSignature));
    });
  });
}
