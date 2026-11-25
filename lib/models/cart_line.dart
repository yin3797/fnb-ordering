import 'package:equatable/equatable.dart';

import 'menu_item.dart';

class CartLine extends Equatable {
  // A snapshot of the item as it was when added, so the cart does not
  // depend on the menu staying loaded. A real server would reprice at checkout.
  final MenuItem item;
  final int quantity;

  const CartLine({required this.item, required this.quantity})
    : assert(quantity > 0, 'A cart line needs at least one item');

  int get lineTotalCents => item.priceCents * quantity;

  CartLine copyWith({int? quantity}) {
    return CartLine(item: item, quantity: quantity ?? this.quantity);
  }

  @override
  List<Object?> get props => [item, quantity];
}
