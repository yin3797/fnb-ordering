import 'dart:developer';

import '../models/app_exception.dart';

/// Reads a list from a server response, one entry at a time.
///
/// [parse] reads one entry and throws if the entry is bad.
///
/// A bad entry is skipped, so a single bad record cannot take a whole screen
/// down. If entries arrived and none could be read, the contract itself has
/// changed, and returning an empty list would hide that, so it throws an
/// [UnexpectedException].
///
/// The log is only visible in debug; a production app would report each
/// skipped entry to monitoring and alert on the count.
List<T> parseList<T>(
  List<dynamic> rawItems,
  T Function(Map<String, dynamic> json) parse,
) {
  final items = <T>[];

  for (final (index, raw) in rawItems.indexed) {
    try {
      items.add(parse(raw as Map<String, dynamic>));
    } catch (error) {
      // Untyped on purpose: a failed cast throws an Error, not an Exception.
      log('Skipped $T at index $index', name: 'parseList', error: error);
    }
  }

  final skipped = rawItems.length - items.length;
  if (skipped > 0) {
    log('Skipped $skipped of ${rawItems.length} $T', name: 'parseList');
  }
  if (rawItems.isNotEmpty && items.isEmpty) {
    throw const UnexpectedException();
  }
  return items;
}
