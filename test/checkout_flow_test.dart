import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fnb_ordering/app.dart';
import 'package:fnb_ordering/cubits/cart_cubit.dart';
import 'package:fnb_ordering/models/app_exception.dart';
import 'package:fnb_ordering/models/cart_line.dart';
import 'package:fnb_ordering/models/menu_category.dart';
import 'package:fnb_ordering/models/menu_item.dart';
import 'package:fnb_ordering/repositories/checkout_repository.dart';
import 'package:fnb_ordering/repositories/menu_repository.dart';
import 'package:fnb_ordering/screens/cart_screen.dart';

class _OneItemMenu implements MenuRepository {
  @override
  Future<List<MenuCategory>> fetchMenu() async => const [
    MenuCategory(
      id: 'drinks',
      name: 'Drinks',
      items: [
        MenuItem(
          id: 1,
          name: 'Coffee',
          description: 'Hot',
          priceCents: 500,
          isAvailable: true,
          thumbnailUrl: '',
        ),
      ],
    ),
  ];
}

class _FourItemMenu implements MenuRepository {
  static const items = [
    MenuItem(
      id: 1,
      name: 'Item 1',
      description: '',
      priceCents: 500,
      isAvailable: true,
      thumbnailUrl: '',
    ),
    MenuItem(
      id: 2,
      name: 'Item 2',
      description: '',
      priceCents: 500,
      isAvailable: true,
      thumbnailUrl: '',
    ),
    MenuItem(
      id: 3,
      name: 'Item 3',
      description: '',
      priceCents: 500,
      isAvailable: true,
      thumbnailUrl: '',
    ),
    MenuItem(
      id: 4,
      name: 'Item 4',
      description: '',
      priceCents: 500,
      isAvailable: true,
      thumbnailUrl: '',
    ),
  ];

  @override
  Future<List<MenuCategory>> fetchMenu() async => const [
    MenuCategory(id: 'food', name: 'Food', items: items),
  ];
}

/// Stays "in flight" until the test completes it.
class _PausedCheckout implements CheckoutRepository {
  int calls = 0;
  var _result = Completer<void>();

  @override
  Future<void> placeOrder(List<CartLine> lines) {
    calls++;
    _result = Completer<void>();
    return _result.future;
  }

  void succeed() => _result.complete();

  void fail(Object error) => _result.completeError(error);
}

void main() {
  late _PausedCheckout checkout;

  // Adds one coffee, opens the cart and taps Place order.
  Future<void> placeOrder(WidgetTester tester) async {
    checkout = _PausedCheckout();
    await tester.pumpWidget(
      App(menuRepository: _OneItemMenu(), checkoutRepository: checkout),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add Coffee'));
    await tester.pump();
    await tester.tap(find.textContaining('View cart'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Place order'));
    await tester.pump();
  }

  testWidgets('a placed order closes the cart and says so once', (
    tester,
  ) async {
    await placeOrder(tester);

    // The button is disabled while the order is being sent.
    await tester.tap(find.byType(FilledButton).last, warnIfMissed: false);
    expect(checkout.calls, 1);

    checkout.succeed();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Your cart is empty.'), findsNothing);

    await tester.pumpAndSettle();
    expect(find.byType(CartScreen), findsNothing);
    expect(find.text('Order placed'), findsOneWidget);
    expect(find.byTooltip('Add Coffee'), findsOneWidget);
  });

  testWidgets('a result that arrives after going back shows on the menu', (
    tester,
  ) async {
    await placeOrder(tester);

    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Placing order…'), findsOneWidget);

    checkout.fail(const NetworkException());
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('View cart · 1 item'), findsOneWidget);

    await tester.tap(find.textContaining('View cart'));
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets(
    'a double tap on the cart bar opens the cart and orders nothing',
    (tester) async {
      checkout = _PausedCheckout();
      await tester.pumpWidget(
        App(menuRepository: _OneItemMenu(), checkoutRepository: checkout),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Add Coffee'));
      await tester.pump();

      // "Place order" arrives exactly where the bar was, so the second tap
      // lands on it while the cart screen is still sliding in.
      final bar = tester.getCenter(find.textContaining('View cart'));
      await tester.tapAt(bar);
      for (var frame = 0; frame < 6; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.tapAt(bar);
      await tester.pump(const Duration(seconds: 1));

      expect(checkout.calls, 0);
      expect(find.byType(CartScreen), findsOneWidget);

      // Once the screen has arrived, the button works.
      await tester.tap(find.text('Place order'));
      await tester.pump();
      expect(checkout.calls, 1);
    },
  );

  testWidgets('swiping a cart line away removes it', (tester) async {
    checkout = _PausedCheckout();
    await tester.pumpWidget(
      App(menuRepository: _OneItemMenu(), checkoutRepository: checkout),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add Coffee'));
    await tester.pump();
    await tester.tap(find.byTooltip('Add one Coffee'));
    await tester.pump();
    await tester.tap(find.textContaining('View cart'));
    await tester.pumpAndSettle();

    await tester.drag(find.text('Coffee'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Your cart is empty.'), findsOneWidget);
  });

  testWidgets('a line swiped away is gone before its animation ends', (
    tester,
  ) async {
    checkout = _PausedCheckout();
    await tester.pumpWidget(
      App(menuRepository: _OneItemMenu(), checkoutRepository: checkout),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add Coffee'));
    await tester.pump();
    await tester.tap(find.textContaining('View cart'));
    await tester.pumpAndSettle();

    // Flick the line away and look before its closing animation has
    // finished. The cart is already empty, so nothing is left to order.
    await tester.fling(find.text('Coffee'), const Offset(-400, 0), 2000);
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(find.text('Place order'), findsNothing);

    await tester.pumpAndSettle();
    expect(find.text('Your cart is empty.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a tap while the cart closes after an order does not reopen it', (
    tester,
  ) async {
    await placeOrder(tester);
    final button = tester.getCenter(find.byType(FilledButton).last);

    checkout.succeed();
    await tester.pump();
    for (var frame = 0; frame < 6; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.tapAt(button);
    await tester.pumpAndSettle();

    expect(find.byType(CartScreen), findsNothing);
    expect(find.text('Order placed'), findsOneWidget);
  });

  testWidgets(
    'a second swipe during the first removal still removes its line',
    (tester) async {
      checkout = _PausedCheckout();
      await tester.pumpWidget(
        App(menuRepository: _FourItemMenu(), checkoutRepository: checkout),
      );
      await tester.pumpAndSettle();

      final cart = tester.element(find.byType(TabBar)).read<CartCubit>();
      for (final item in _FourItemMenu.items) {
        cart.add(item);
      }
      await tester.pump();
      await tester.pump();
      await tester.tap(find.textContaining('View cart'));
      await tester.pumpAndSettle();

      // Swipe one line, then another while the list is still closing the gap.
      await tester.fling(find.text('Item 1'), const Offset(-400, 0), 2000);
      for (var frame = 0; frame < 10; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.fling(find.text('Item 3'), const Offset(-400, 0), 2000);
      await tester.pumpAndSettle();

      expect(cart.state.lines.map((line) => line.item.id), [2, 4]);
      expect(tester.takeException(), isNull);
    },
  );
}
