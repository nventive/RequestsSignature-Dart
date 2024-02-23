// Dart core library imports
import 'dart:async';
import 'dart:typed_data';

import 'package:requests_signature_dart/src/core/implementation/signature_body_source_parameters.dart';

/// Builds the source for the signature body.
abstract class ISignatureBodySourceBuilder {
  /// Builds the source value for the signature body.
  ///
  /// The [parameters] represent the [SignatureBodySourceParameters].
  ///
  /// Returns the source value that needs to be signed.
  Future<Uint8List> build(SignatureBodySourceParameters parameters);
}
