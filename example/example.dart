import 'package:requests_signature_dart/requests_signature_dart.dart';
import 'package:requests_signature_dart/src/client/requests_signature_options.dart';
import 'package:dio/dio.dart';

void main() {
  // Instantiate Dio client.
  final dio = Dio();

  // Define signature options.
  final signatureOptions = RequestsSignatureOptions(
    clientId: 'your_client_id', // Your unique client ID
    clientSecret: 'your_client_secret', // Your client secret key
    headerName:
        'X-Request-Signature', // Name of the custom header for the signature
    signaturePattern:
        '{ClientId}:{Nonce}:{Timestamp}:{SignatureBody}', // Pattern for the signature header value
    clockSkew: Duration(
        seconds: 30), // Clock skew duration (30 seconds in this example)
    disableAutoRetryOnClockSkew:
        false, // Disable auto retry on clock skew if set to true
  );

  // Instantiate interceptor.
  final interceptor = RequestsSignatureInterceptor(
    signatureOptions,
    dio,
  );

  // Add interceptor to Dio client.
  dio.interceptors.add(interceptor);
}
