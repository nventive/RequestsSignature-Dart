import 'package:requests_signature_dart/src/core/implementation/signature_body_source_components.dart';

/// Holds common constants used in request signature handling.
class DefaultConstants {
  /// The default header name used for request signature (X-RequestSignature).
  static const String headerName = "X-RequestSignature";

  /// The default pattern for the request signature header ({ClientId}:{Nonce}:{Timestamp}:{SignatureBody}).
  static const String signaturePattern =
      "{ClientId}:{Nonce}:{Timestamp}:{SignatureBody}";

  /// The default list of components used to generate the signature body.
  static List<String> get signatureBodySourceComponents {
    return [
      SignatureBodySourceComponents.nonce,
      SignatureBodySourceComponents.timestamp,
      SignatureBodySourceComponents.method,
      SignatureBodySourceComponents.scheme,
      SignatureBodySourceComponents.host,
      SignatureBodySourceComponents.localPath,
      SignatureBodySourceComponents.queryString,
      SignatureBodySourceComponents.body
    ];
  }

  /// The default clock skew used for request signature validation (5 minutes).
  static const Duration clockSkew = Duration(minutes: 5);
}
