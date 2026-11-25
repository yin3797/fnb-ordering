import 'package:flutter/material.dart';

import '../../models/cart_line.dart';
import '../format.dart';
import 'item_thumbnail.dart';
import 'quantity_stepper.dart';

/// One line in the cart: what it is, how many, and what the line costs.
///
/// The stepper is the only control on the line; taking the last one out
/// removes it. The cart screen also lets a line be swiped away. The
/// callbacks are null while an order is being sent, which disables the line.
class CartLineTile extends StatelessWidget {
  final CartLine line;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  const CartLineTile({
    super.key,
    required this.line,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = line.item;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ItemThumbnail(url: item.thumbnailUrl, size: 64),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: theme.textTheme.titleMedium!.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // The price sits beside the stepper when it fits and drops
                // below it on a narrow screen or at a large text size.
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    children: [
                      QuantityStepper(
                        itemName: item.name,
                        quantity: line.quantity,
                        onDecrement: onDecrement,
                        onIncrement: onIncrement,
                      ),
                      _LinePrice(line: line),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The line total, with the unit price under it once there is more than
/// one. At quantity 1 the unit price would only repeat the total.
///
/// The unit price keeps its space even while hidden, so a line does not
/// change height when the quantity goes from one to two and nothing moves
/// under the customer's finger.
class _LinePrice extends StatelessWidget {
  final CartLine line;

  const _LinePrice({required this.line});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // A price is never cut short: it shrinks to fit instead.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            formatMoney(line.lineTotalCents),
            style: theme.textTheme.titleMedium,
          ),
          Visibility(
            visible: line.quantity > 1,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: Text(
              '${formatMoney(line.item.priceCents)} each',
              style: theme.textTheme.bodySmall!.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
