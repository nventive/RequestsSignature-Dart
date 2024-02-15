# HMAC Signed requests in dart

This Dart package provides a convenient way to make HTTP requests with HMAC authentication. HMAC (Hash-based Message Authentication Code) authentication is a mechanism for verifying the authenticity of a message using a cryptographic hash function and a secret key.

## Features

- Supports HMAC authentication for secure requests in HTTP and HTTPS.
- Core Encryption Algorithm is SHA-256.
- Provides classes for GET, POST, PUT, and DELETE requests with HMAC authentication.
- Easily configurable and customizable for different APIs.
- Depends on [crypto](https://pub.dev/packages/crypto) and [http](https://pub.dev/packages/http).

## Installation

### Use this package as a library.

Depend on it

##### Run this command:

```
flutter pub add requests_signature_dart
```

This will add a line like this to your package's `pubspec.yaml` (and run an implicit `flutter pub get`):

```
dependencies:
  request_signature_dart: ^1.0.0
```
Alternatively, your editor might support `flutter pub get`. Check the docs for your editor to learn more.

##### Import it 

in your dart code:

```
import 'package:requests_signature_dart/request_signature_dart.dart';
```

## Usage

### In your dart code

```
import 'package:requests_signature_dart/requests_signature_dart.dart';

void main() async {
  // Initialize SignedHMACRequest with your API key and secret
  final signedRequest = SignedHMACRequest(apiKey, apiSecret);

  // Make a GET request
  final getRequest = signedRequest.get('https://api.example.com/endpoint');
  final getResponse = await getRequest.send();
  print(getResponse.body);

  // Make a POST request
  final postRequest = signedRequest.post('https://api.example.com/endpoint');
  final postResponse = await postRequest.send(body: {'key': 'value'});
  print(postResponse.body);

  // Similar usage for PUT and DELETE requests
}

```

## Breaking Changes

Please consult [BREAKING_CHANGES.md](BREAKING_CHANGES.md) for more information about version.

## License

This project is licensed under the Apache 2.0 [License](LICENSE) - see the LICENSE file for details.

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on the process for contributing to this project.
Be mindful of our [Code of Conduct](CODE_OF_CONDUCT.md).