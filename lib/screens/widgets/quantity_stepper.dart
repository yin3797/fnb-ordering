import 'package:flutter/material.dart';

/// A round "+" that opens into "− 2 +" inside a thin outline. Shared by the
/// menu and the cart.
///
/// Only the "+" carries colour: adding is the action to encourage. It is the
/// same button in both states and stays in the same place, so repeated taps
/// always land on it. Taking the last one out removes the item.
///
/// Material 3 has no quantity stepper, so this is built from its icon
/// buttons. A null callback disables that button, which is how both stop
/// while an order is being sent.
class QuantityStepper extends StatelessWidget {
  final String itemName;
  final int quantity;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  const QuantityStepper({
    super.key,
    required this.itemName,
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    final add = IconButton.filledTonal(
      onPressed: onIncrement,
      tooltip: quantity == 0 ? 'Add $itemName' : 'Add one $itemName',
      icon: const Icon(Icons.add),
    );
    if (quantity == 0) return add;

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final enabled = onDecrement != null || onIncrement != null;

    // Each button keeps a 48 px touch area. The outline behind them is 40 px
    // tall, the same as the round "+".
    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  shape: StadiumBorder(
                    side: BorderSide(color: colors.outlineVariant),
                  ),
                ),
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: onDecrement,
                tooltip: 'Remove one $itemName',
                color: colors.onSurfaceVariant,
                icon: const Icon(Icons.remove),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 24),
                child: Semantics(
                  label: 'Quantity $quantity',
                  excludeSemantics: true,
                  // The number stops growing at 1.3 times. Larger than that
                  // and the stepper squeezes the price beside it on a narrow
                  // phone.
                  child: MediaQuery.withClampedTextScaling(
                    maxScaleFactor: 1.3,
                    child: Text(
                      '$quantity',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium!.copyWith(
                        color: enabled
                            ? colors.onSurface
                            : colors.onSurface.withValues(alpha: 0.38),
                      ),
                    ),
                  ),
                ),
              ),
              add,
            ],
          ),
        ],
      ),
    );
  }
}
