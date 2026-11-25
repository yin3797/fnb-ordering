import '../models/app_exception.dart';

const _genericMessage = 'Something went wrong. Please try again.';

/// The one place that decides what the customer reads when something fails.
///
/// The wording is fixed here for every error except a rejected request, whose
/// reason comes from the server. The switch has no default, so adding an
/// error type will not compile until it is given a message.
String errorMessage(AppException error) {
  return switch (error) {
    NetworkException() => "Can't connect. Check your connection and try again.",
    ServerException() =>
      'The service is having a problem. Please try again shortly.',
    // A blank reason would show the customer an empty message.
    RequestRejectedException(:final reason) =>
      reason.trim().isEmpty ? _genericMessage : reason,
    UnexpectedException() => _genericMessage,
  };
}
