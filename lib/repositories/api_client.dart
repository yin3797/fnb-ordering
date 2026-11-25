import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/app_exception.dart';

/// The one place that talks HTTP.
///
/// Every repository that calls a server sends its requests through here, so
/// the timeout, the status check, the decoding and the error mapping are
/// written once.
class ApiClient {
  final http.Client _client;
  final Duration timeout;

  ApiClient(this._client, {this.timeout = const Duration(seconds: 10)});

  /// Returns the decoded JSON object, or throws an [AppException].
  Future<Map<String, dynamic>> getJson(Uri uri) async {
    try {
      final response = await _client.get(uri).timeout(timeout);
      if (!_isSuccess(response.statusCode)) {
        throw ServerException(response.statusCode);
      }

      // Decoded from the bytes as UTF-8, so accented text does not depend on
      // the server sending a charset header.
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    } catch (error, stackTrace) {
      // Untyped on purpose: a body that is not a JSON object fails the cast
      // with an Error, not an Exception. The original stack trace is kept so
      // a crash report points at the real cause.
      Error.throwWithStackTrace(_toAppException(error, stackTrace), stackTrace);
    }
  }

  bool _isSuccess(int statusCode) => statusCode >= 200 && statusCode < 300;

  // Sorts any failure into one of the app's own error types.
  AppException _toAppException(Object error, StackTrace stackTrace) {
    switch (error) {
      case AppException():
        return error;

      // ClientException: no connection, failed host lookup, dropped
      // connection. IOException: a failed TLS handshake, which the http
      // package does not wrap; it happens on Wi-Fi that needs a login page or
      // when the device clock is wrong.
      case TimeoutException() || http.ClientException() || IOException():
        return const NetworkException();

      default:
        // Only visible in debug; a production app would send this to a crash
        // reporter here.
        log(
          'Request failed unexpectedly',
          name: 'ApiClient',
          error: error,
          stackTrace: stackTrace,
        );
        return const UnexpectedException();
    }
  }
}
