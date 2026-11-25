import 'dart:developer';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/app_exception.dart';
import '../models/cart_line.dart';
import '../models/menu_item.dart';
import '../models/price_summary.dart';
import '../repositories/checkout_repository.dart';

part 'cart_state.dart';

class CartCubit extends Cubit<CartState> {
  final CheckoutRepository _repository;

  CartCubit(this._repository) : super(const CartState());

  /// Puts one more of [item] in the cart.
  ///
  /// Does nothing while an order is being sent, or if the item is sold out.
  /// There is no upper limit here: how many can be ordered is the server's
  /// decision. A real server would refuse an order it cannot fulfil.
  void add(MenuItem item) {
    if (state.isSubmitting || !item.isAvailable) return;

    final quantity = state.quantityOf(item.id);

    if (quantity == 0) {
      _setLines([...state.lines, CartLine(item: item, quantity: 1)]);
    } else {
      _setQuantity(item.id, quantity + 1);
    }
  }

  /// Takes one of the item out. Taking the last one removes the line.
  void decrement(int itemId) {
    if (state.isSubmitting) return;

    final quantity = state.quantityOf(itemId);
    if (quantity == 0) return;

    if (quantity == 1) {
      remove(itemId);
    } else {
      _setQuantity(itemId, quantity - 1);
    }
  }

  /// Removes the whole line, whatever its quantity. Reached by swiping a
  /// cart line away, by the screen-reader action, and by [decrement] at
  /// quantity 1.
  void remove(int itemId) {
    if (state.isSubmitting) return;
    if (state.quantityOf(itemId) == 0) return;

    _setLines([
      for (final line in state.lines)
        if (line.item.id != itemId) line,
    ]);
  }

  /// Sends the cart as an order.
  ///
  /// The two checks and the move to "submitting" all happen before the first
  /// `await`. Dart runs that stretch without interruption, so a second tap
  /// arrives after the status has already changed and is refused.
  Future<void> placeOrder() async {
    if (state.isSubmitting || state.isEmpty) return;

    final lines = state.lines;
    emit(state.copyWith(status: const CheckoutSubmitting()));

    AppException? failure;
    try {
      await _repository.placeOrder(lines);
    } on AppException catch (error) {
      failure = error;
    } catch (error, stackTrace) {
      // A repository should only throw an AppException. Without this, any
      // other error would leave the cart locked on "submitting" for good.
      log(
        'Checkout failed',
        name: 'CartCubit',
        error: error,
        stackTrace: stackTrace,
      );
      failure = const UnexpectedException();
    }

    // The Cubit may have been closed while the request was running.
    if (isClosed) return;

    // The result is emitted outside the try, so a problem while emitting can
    // never turn an accepted order into a reported failure.
    if (failure == null) {
      emit(const CartState(status: CheckoutSucceeded()));
    } else {
      // The lines are kept, so the customer can change the cart or try again.
      emit(state.copyWith(status: CheckoutFailed(failure)));
    }
  }

  void _setQuantity(int itemId, int quantity) {
    _setLines([
      for (final line in state.lines)
        if (line.item.id == itemId) line.copyWith(quantity: quantity) else line,
    ]);
  }

  // Always a new list, never the old one changed in place: a Cubit ignores an
  // emit whose state equals the current one.
  //
  // Building a fresh CartState is deliberate. An edit returns the status to
  // idle, so the result of an earlier order stops showing once the cart
  // changes. A future field that must survive an edit needs copyWith here.
  void _setLines(List<CartLine> lines) {
    emit(CartState(lines: List.unmodifiable(lines)));
  }
}
