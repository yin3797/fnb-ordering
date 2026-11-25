import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../cubits/cart_cubit.dart';
import '../format.dart';

/// "View cart · 3 items · RM12.00", always at the bottom of the menu. It
/// reads "Your cart is empty" until something is added.
///
/// It is there even when the cart is empty. A bar that appeared on the first
/// add would slide in under the customer's finger, so a second tap on the
/// same "+" would open the cart instead of adding another.
///
/// The screen that shows the bar decides where a tap goes.
class CartBar extends StatelessWidget {
  final VoidCallback onPressed;

  const CartBar({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    // The bar listens to exactly what it shows and nothing else.
    return BlocSelector<CartCubit, CartState, (int, int, bool)>(
      selector: (cart) =>
          (cart.itemCount, cart.summary.totalCents, cart.isSubmitting),
      builder: (context, selected) {
        final (itemCount, totalCents, isSubmitting) = selected;

        // While an order is being sent the menu's buttons are disabled, and
        // this label is what tells the customer why.
        final String label;
        if (isSubmitting) {
          label = 'Placing order…';
        } else if (itemCount == 0) {
          label = 'Your cart is empty';
        } else {
          label =
              'View cart · ${formatItemCount(itemCount)} · '
              '${formatMoney(totalCents)}';
        }

        final colors = Theme.of(context).colorScheme;

        return SafeArea(
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: SizedBox(
                  width: double.infinity,
                  // Quieter while there is nothing in the cart.
                  child: FilledButton(
                    style: itemCount == 0
                        ? FilledButton.styleFrom(
                            backgroundColor: colors.surfaceContainerHigh,
                            foregroundColor: colors.onSurfaceVariant,
                          )
                        : null,
                    onPressed: onPressed,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      // The text shrinks to fit at very large text sizes, so
                      // the total is never cut off. The box keeps one height
                      // whatever the label, so the bar never changes size
                      // while the customer is tapping near it.
                      //
                      // The bar is always on screen, so its text stops
                      // growing at 1.5 times, like the order summary.
                      child: MediaQuery.withClampedTextScaling(
                        maxScaleFactor: 1.5,
                        child: Builder(
                          builder: (context) => SizedBox(
                            height: MediaQuery.textScalerOf(context).scale(20),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(label),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
