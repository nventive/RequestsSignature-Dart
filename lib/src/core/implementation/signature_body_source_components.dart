/// Constants representing different components of a signature body source.
///
/// This class provides constants representing various components that can be included
/// in a signature body source for building signatures.
class SignatureBodySourceComponents {
  /// Represents the HTTP method component.
  static const String method = 'Method';

  /// Represents the URI scheme component.
  static const String scheme = 'Scheme';

  /// Represents the URI host component.
  static const String host = 'Host';

  /// Represents the URI port component.
  static const String port = 'Port';

  /// Represents the URI local path component.
  static const String localPath = 'LocalPath';

  /// Represents the URI query string component.
  static const String queryString = 'QueryString';

  /// Represents the request body component.
  static const String body = 'Body';

  /// Represents the timestamp component.
  static const String timestamp = 'Timestamp';

  /// Represents the nonce component.
  static const String nonce = 'Nonce';

  /// Constructs the header component based on the given [headerName].
  ///
  /// Returns a string representing the header component with the provided name.
  static String header(String headerName) => headerName;

  /// Checks if the provided [component] is a header component.
  ///
  /// If [headerName] is provided, it is updated with the name of the header component.
  /// Returns true if the component is a header component, false otherwise.
  static bool isHeader(String component, String? headerName) {
    if (component.isEmpty) {
      return false;
    }

    if (component.startsWith('Header')) {
      headerName = component.substring('Header'.length);
      return true;
    }

    return false;
  }
}
