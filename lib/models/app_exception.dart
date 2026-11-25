import 'package:equatable/equatable.dart';

/// The only error type that leaves a repository.
///
/// Typed by what the customer can do about it, not by endpoint.
sealed class AppException extends Equatable implements Exception {
  const AppException();

  @override
  List<Object?> get props => [];

  // Without this, a release build prints only the type name and the status
  // code is lost from logs.
  @override
  bool get stringify => true;
}

/// No connection, or the request timed out.
final class NetworkException extends AppException {
  const NetworkException();
}

/// The server answered with a failure status and no reason the app can show.
final class ServerException extends AppException {
  final int statusCode;

  const ServerException(this.statusCode);

  @override
  List<Object?> get props => [statusCode];
}

/// The server understood the request and refused it, with a reason to show.
///
/// Not tied to one endpoint: an order over the limit, an expired promo code
/// and a sold-out item are all this case. Retrying unchanged gets the same
/// answer, so the customer has to change something.
final class RequestRejectedException extends AppException {
  final String reason;

  const RequestRejectedException(this.reason);

  @override
  List<Object?> get props => [reason];
}

/// Anything else, such as a response in a shape the app does not expect.
final class UnexpectedException extends AppException {
  const UnexpectedException();
}
