import '../models/app_exception.dart';
import '../models/cart_line.dart';
import 'checkout_repository.dart';

/// Stands in for an order API, which is out of scope.
///
/// It waits, then accepts the order. An order above the limit is rejected,
/// so both outcomes can be reproduced from inside the app.
class SimulatedCheckoutRepository implements CheckoutRepository {
  final Duration delay;

  const SimulatedCheckoutRepository({
    this.delay = const Duration(milliseconds: 1500),
  });

  static const _orderLimitCents = 100000;

  // Plays the part of the server's own message, so it is plain text and not
  // built with the app's money formatting. Keep it in step with the limit.
  static const _orderLimitMessage = "Orders over RM1,000 can't be placed.";

  @override
  Future<void> placeOrder(List<CartLine> lines) async {
    // Priced before the wait, as a server prices the request it received.
    // A real server works out the total itself and never trusts the app's.
    final totalCents = lines.fold(0, (sum, line) => sum + line.lineTotalCents);

    await Future<void>.delayed(delay);

    if (totalCents > _orderLimitCents) {
      throw const RequestRejectedException(_orderLimitMessage);
    }
  }
}
