part of 'cart_cubit.dart';

/// The cart lines exist in every situation, so this is one class that holds
/// them plus a status, and not one class per situation.
class CartState extends Equatable {
  final List<CartLine> lines;
  final CheckoutStatus status;

  const CartState({this.lines = const [], this.status = const CheckoutIdle()});

  bool get isEmpty => lines.isEmpty;

  bool get isSubmitting => status is CheckoutSubmitting;

  // The number of items, not the number of lines: 2 coffees and 1 tea is 3.
  int get itemCount => lines.fold(0, (sum, line) => sum + line.quantity);

  // Worked out from the lines each time and never stored, so the total
  // cannot disagree with the cart.
  PriceSummary get summary => PriceSummary.from(lines);

  // Lines are matched by the item's id, not by comparing whole items.
  int quantityOf(int itemId) {
    for (final line in lines) {
      if (line.item.id == itemId) return line.quantity;
    }
    return 0;
  }

  CartState copyWith({List<CartLine>? lines, CheckoutStatus? status}) {
    return CartState(lines: lines ?? this.lines, status: status ?? this.status);
  }

  @override
  List<Object?> get props => [lines, status];
}

/// Where the order is.
///
/// The error lives inside [CheckoutFailed] and not in a separate field on
/// [CartState]: `copyWith` cannot set a field back to null, so a separate
/// error could linger after the cart moved on.
sealed class CheckoutStatus extends Equatable {
  const CheckoutStatus();

  @override
  List<Object?> get props => [];
}

/// The cart can be edited and no order result is showing.
final class CheckoutIdle extends CheckoutStatus {
  const CheckoutIdle();
}

/// The order is being sent. Every cart action is refused.
final class CheckoutSubmitting extends CheckoutStatus {
  const CheckoutSubmitting();
}

/// The order was placed and the cart is empty.
final class CheckoutSucceeded extends CheckoutStatus {
  const CheckoutSucceeded();
}

/// The order was not confirmed. The cart is intact and can be edited.
///
/// "Not confirmed" and not "not placed": after a timeout the server may
/// still have accepted it.
final class CheckoutFailed extends CheckoutStatus {
  final AppException error;

  const CheckoutFailed(this.error);

  @override
  List<Object?> get props => [error];
}
