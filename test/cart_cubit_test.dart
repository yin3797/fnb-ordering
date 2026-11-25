import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fnb_ordering/cubits/cart_cubit.dart';
import 'package:fnb_ordering/models/app_exception.dart';
import 'package:fnb_ordering/models/cart_line.dart';
import 'package:fnb_ordering/models/menu_item.dart';
import 'package:fnb_ordering/repositories/checkout_repository.dart';

/// A checkout that stays "in flight" until the test completes it, so the
/// Cubit can be checked while a request is still running.
class _PausedCheckout implements CheckoutRepository {
  int calls = 0;
  final _result = Completer<void>();

  @override
  Future<void> placeOrder(List<CartLine> lines) {
    calls++;
    return _result.future;
  }

  void succeed() => _result.complete();

  void fail(Object error) => _result.completeError(error);
}

const _coffee = MenuItem(
  id: 1,
  name: 'Coffee',
  description: 'Hot',
  priceCents: 500,
  isAvailable: true,
  thumbnailUrl: '',
);

void main() {
  late _PausedCheckout checkout;
  late CartCubit cart;

  // Every test starts with two coffees in the cart.
  setUp(() {
    checkout = _PausedCheckout();
    cart = CartCubit(checkout)
      ..add(_coffee)
      ..add(_coffee);
  });

  tearDown(() => cart.close());

  test('tapping Place Order several times sends one order', () async {
    final first = cart.placeOrder();
    final second = cart.placeOrder();
    final third = cart.placeOrder();

    expect(checkout.calls, 1);
    expect(cart.state.isSubmitting, isTrue);

    checkout.succeed();
    await Future.wait([first, second, third]);

    expect(checkout.calls, 1);
    expect(cart.state.status, const CheckoutSucceeded());
    expect(cart.state.isEmpty, isTrue);
  });

  test('the cart cannot be edited while the order is being sent', () async {
    final order = cart.placeOrder();

    cart.add(_coffee);
    expect(cart.state.quantityOf(_coffee.id), 2);

    cart.decrement(_coffee.id);
    expect(cart.state.quantityOf(_coffee.id), 2);

    cart.remove(_coffee.id);
    expect(cart.state.quantityOf(_coffee.id), 2);

    expect(cart.state.isSubmitting, isTrue);

    checkout.succeed();
    await order;
  });

  test('a rejected order keeps the cart and carries the reason', () async {
    const rejection = RequestRejectedException('Too large.');

    final order = cart.placeOrder();
    checkout.fail(rejection);
    await order;

    expect(cart.state.status, const CheckoutFailed(rejection));
    expect(cart.state.quantityOf(_coffee.id), 2);
  });

  test('an unknown error ends in failed, not stuck on submitting', () async {
    final order = cart.placeOrder();
    checkout.fail(StateError('not an AppException'));
    await order;

    expect(cart.state.status, const CheckoutFailed(UnexpectedException()));
    expect(cart.state.quantityOf(_coffee.id), 2);
  });

  test('closing the Cubit while the order is in flight is safe', () async {
    final order = cart.placeOrder();

    await cart.close();
    checkout.succeed();

    await expectLater(order, completes);
  });

  test('an empty cart sends nothing', () async {
    final emptyCart = CartCubit(checkout);
    addTearDown(emptyCart.close);

    await emptyCart.placeOrder();

    expect(checkout.calls, 0);
    expect(emptyCart.state, const CartState());
  });

  test('remove clears a line at any quantity', () {
    cart.remove(_coffee.id);

    expect(cart.state.isEmpty, isTrue);
  });

  test('a sold-out item cannot be added', () {
    const soldOut = MenuItem(
      id: 2,
      name: 'Matcha cake',
      description: 'Gone for today',
      priceCents: 1500,
      isAvailable: false,
      thumbnailUrl: '',
    );

    cart.add(soldOut);

    expect(cart.state.quantityOf(soldOut.id), 0);
  });
}
