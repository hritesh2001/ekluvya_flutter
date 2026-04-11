/// Base exception for all app-level errors.
/// Using a typed hierarchy instead of raw strings means ViewModels and screens
/// can respond differently to network vs. server vs. parse failures.
abstract class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => message;
}

/// Device has no active network connection.
class NetworkException extends AppException {
  const NetworkException()
      : super(
          'No internet connection. Please check your network and try again.',
        );
}

/// HTTP request exceeded the configured timeout.
class RequestTimeoutException extends AppException {
  const RequestTimeoutException()
      : super('Request timed out. Please try again.');
}

/// Server returned a non-success status or an unexpected payload.
class ServerException extends AppException {
  const ServerException(super.message);
}

/// Response body could not be decoded (e.g. server returned HTML).
class ParseException extends AppException {
  const ParseException()
      : super('Unexpected server response. Please try again.');
}
