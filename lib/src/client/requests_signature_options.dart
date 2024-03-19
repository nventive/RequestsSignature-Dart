import 'dart:core';

import 'package:requests_signature_dart/src/core/default_constants.dart';

/// Options for signing requests.
class RequestsSignatureOptions {
  /// Client id.
  String? clientId;

  /// Client secret.
  String? clientSecret;

  /// Header name.
  String headerName = DefaultConstants.headerName;

  /// Header signature pattern.
  String signaturePattern = DefaultConstants.signaturePattern;

  /// Allowed lag of time in either direction (past/future)
  /// where the request is still considered valid.
  ///
  /// Defaults to [DefaultConstants.clockSkew] (5 minutes).
  Duration clockSkew = DefaultConstants.clockSkew;

  /// Indicates whether to disable auto-retries on clock skew detection.
  bool disableAutoRetryOnClockSkew = false;

  /// Ordered list of signature body source components used to compute
  /// the value that will be signed and create the signature body.
  List<String> signatureBodySourceComponents = [];

  /// Constructor for RequestsSignatureOptions.
  RequestsSignatureOptions({
    this.clientId,
    this.clientSecret,
    String? headerName,
    String? signaturePattern,
    Duration? clockSkew,
    bool? disableAutoRetryOnClockSkew,
    List<String>? signatureBodySourceComponents,
  }) {
    if (headerName != null) this.headerName = headerName;
    if (signaturePattern != null) this.signaturePattern = signaturePattern;
    if (clockSkew != null) this.clockSkew = clockSkew;
    if (disableAutoRetryOnClockSkew != null) {
      this.disableAutoRetryOnClockSkew = disableAutoRetryOnClockSkew;
    }
    if (signatureBodySourceComponents != null) {
      this.signatureBodySourceComponents = signatureBodySourceComponents;
    }
  }
}
