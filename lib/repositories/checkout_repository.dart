import '../models/cart_line.dart';

abstract interface class CheckoutRepository {
  /// Places an order for [lines].
  ///
  /// Throws an `AppException` if the order is not accepted.
  Future<void> placeOrder(List<CartLine> lines);
}
