import 'package:dio/dio.dart';
import 'package:requests_signature_dart/src/client/dio_interceptor.dart';
import 'package:requests_signature_dart/src/client/requests_signature_options.dart';
import 'package:requests_signature_dart/src/core/interface/signature_body_signer.dart';
import 'package:requests_signature_dart/src/core/interface/signature_body_source_builder.dart';

/// Extension methods for Dio.
extension DioExtension on Dio {
  /// Adds [RequestsSignatureInterceptor] as an interceptor in the Dio client.
  ///
  /// [options] - The [RequestsSignatureOptions] to use. If not provided, will retrieve from the container.
  ///
  /// [signatureBodySourceBuilder] - The [ISignatureBodySourceBuilder]. If not provided, will try to retrieve from the container.
  ///
  /// [signatureBodySigner] - The [ISignatureBodySigner]. If not provided, will try to retrieve from the container.
  void addRequestsSignatureInterceptor(
      {RequestsSignatureOptions? options,
      ISignatureBodySourceBuilder? signatureBodySourceBuilder,
      ISignatureBodySigner? signatureBodySigner}) {
    interceptors.add(RequestsSignatureInterceptor(
      options!,
      signatureBodySourceBuilder: signatureBodySourceBuilder!,
      signatureBodySigner: signatureBodySigner!,
    ));
  }
}
