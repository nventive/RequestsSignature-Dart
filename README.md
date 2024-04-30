# RequestsSignature-Dart

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg?style=flat-square)](LICENSE) [![Pub Package](https://img.shields.io/pub/v/requests_signature_dart.svg?style=flat-square)](https://pub.dartlang.org/packages/requests_signature_dart) [![package publisher](https://img.shields.io/pub/publisher/requests_signature_dart.svg?style=flat-square)](https://pub.dev/packages/requests_signature_dart/publisher)

Signs and validates HTTP requests.

This projects can help you implements [HMAC](https://en.wikipedia.org/wiki/HMAC) signatures to HTTP requests on flutter projects.

For backend systems done in .NET, use the [RequestsSignature](https://github.com/nventive/RequestsSignature) library to implement [HMAC](https://en.wikipedia.org/wiki/HMAC) signatures.

## Getting Started

### Implementing Requests Signature Validation in Dart/Flutter app project:

Install the package:

```
flutter pub add requests_signature_dart
```

This will add a line like this to your package's `pubspec.yaml` (and run an implicit `flutter pub get`):

```yaml
dependencies:
  requests_signature_dart: ^1.0.0
```
Alternatively, your editor might support `flutter pub get`. Check the docs for your editor to learn more.

Then do the following to add a `RequestsSignatureInterceptor` to your Dio client.

```dart
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
    headerName: 'X-Request-Signature', // Name of the custom header for the signature
    signaturePattern: '{ClientId}:{Nonce}:{Timestamp}:{SignatureBody}', // Pattern for the signature header value
    clockSkew: Duration(seconds: 30), // Clock skew duration (30 seconds in this example)
    disableAutoRetryOnClockSkew: false, // Disable auto retry on clock skew if set to true
  );

  // Instantiate interceptor.
  final interceptor = RequestsSignatureInterceptor(
    signatureOptions,
    dio,
  );

  // Add interceptor to Dio client.
  dio.interceptors.add(interceptor);
}
```

## Features

### Default Header signature and algorithm

By default, here is how the header is constructed:

The final header has the following specification: `{ClientId}:{Nonce}:{Timestamp}:{SignatureBody}` where:
- `{ClientId}`: is the client id as specified by the configuration
- `{Nonce}`: is a random value unique to each request (a UUID/GUID is perfectly suitable)
- `{Timestamp}`: is the current time when the request is sent, in Unix Epoch time (in seconds)
- `{SignatureBody}`: Is the Base-64 encoded value of the HMAC SHA256 Signature of the signature components

Signature components (the source for the SignatureBody HMAC value) is a binary value composed of the following values sequentially:
- Nonce: UTF-8 encoded binary values of the Nonce
- Timestamp: UTF-8 encoded binary values of the Timestamp (as a string value)
- Request method: UTF-8 encoded binary values of the **uppercase** Request method
- Request scheme: UTF-8 encoded binary values of the Request Uri scheme (e.g. `https`)
- Request host: UTF-8 encoded binary values of the Request Uri host (e.g. `example.org`)
- Request local path: UTF-8 encoded binary values of the Request Uri local path (e.g. `/api/v1/users`)
- Request query string: UTF-8 encoded binary values of the Request Query string, including the leading `?` (e.g. `?q=search`)
- Request body: Raw bytes of the request body

*For more information see the [`SignatureBodySourceBuilder`](lib/src/core/implementation/signature_body_source_builder.dart) class.

*See the Configuration section on how to customize the signature.*

### Auto retry on clock skew detection (client)

The `RequestsSignatureDelegatingHandler` has a specific features that tries to detect
when a client's clock is not properly synchronized with the server and compensate
for the delta. This is useful when dealing with clients that are not under your control.

The way this work is when the client receives either a 401 or 403 status code and the 
response includes a Date header, it compares the date received from the server and the
client current time. If the difference is more than the configured `clockSkew`, it
computes the delta, adjust the time based on the computation and automatically re-tries
the request. All subsequent invocation will also apply the same time delta, until another 
potential clock skew is detected.

This behavior can be de-activated using the `disableAutoRetryOnClockSkew` client option.

### Configuration options

**It is important to properly synchronize the settings between the server and all the clients, otherwise the signature will be improperly computed and compared.**

#### Client-side

- `clockSkew`: The duration of time that a timestamp will still be considered valid when
  comparing with the current time (+/-). Defaults to 5 minutes.
- `headerName`: The name of the header that contains the signature. Defaults to `X-RequestSignature`.
- `signaturePattern`: The pattern that is used to create the final header value.
  Defaults to `{ClientId}:{Nonce}:{Timestamp}:{SignatureBody}`.
- `disableAutoRetryOnClockSkew`: When set to true, the handler will not attempt to 
  detect clock skew and auto-retry.

### Further customization

It is possible to further customize the behavior of the component by providing 
custom implementation of the following interfaces:

- `ISignatureBodySourceBuilder`: Builds the source data for the signature computation
- `ISignatureBodySigner`: Creates the signature body value (from the signature body source)
- `IRequestsSignatureValidationService`: Performs the signature validation

Additionally, the Hash algorithm used can be customized by constructing the 
`HashAlgorithmSignatureBodySigner` using a custom `hashAlgorithmBuilder`:

```csharp
import 'package:requests_signature_dart/requests_signature_dart.dart';
import 'package:dio/dio.dart';
import 'package:cryptography/cryptography.dart';

void main() {
  final dio = Dio();

  [...]

  var customSignatureBodySigner = HashAlgorithmSignatureBodySigner(hmacAlgorithm: DartHmac.sha256());

  // Instantiate interceptor.
  final interceptor = RequestsSignatureInterceptor(
    signatureOptions,
    dio,
    signatureBodySigner: customSignatureBodySigner
  );

  [...]
}
```

## Changelog

Please consult the [CHANGELOG](CHANGELOG.md) for more information about version
history.

## License

This project is licensed under the Apache 2.0 license - see the
[LICENSE](LICENSE) file for details.

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on the process for
contributing to this project.

Be mindful of our [Code of Conduct](CODE_OF_CONDUCT.md).
