import 'package:equatable/equatable.dart';

import 'cart_line.dart';

/// What the cart costs, worked out from its lines.
///
/// It is calculated whenever it is needed and never stored, so it cannot go
/// out of date. Subtotal and total are the same today; a discount, tax or
/// fee would sit between them.
class PriceSummary extends Equatable {
  final int subtotalCents;
  final int totalCents;

  const PriceSummary({required this.subtotalCents, required this.totalCents});

  factory PriceSummary.from(List<CartLine> lines) {
    final subtotalCents = lines.fold(
      0,
      (sum, line) => sum + line.lineTotalCents,
    );
    return PriceSummary(
      subtotalCents: subtotalCents,
      totalCents: subtotalCents,
    );
  }

  @override
  List<Object?> get props => [subtotalCents, totalCents];
}
