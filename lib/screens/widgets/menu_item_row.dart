import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../cubits/cart_cubit.dart';
import '../../models/menu_item.dart';
import '../format.dart';
import '../menu_layout.dart';
import 'item_thumbnail.dart';
import 'quantity_stepper.dart';

/// One item on the menu: the picture on the left, and the name, description
/// and price in one column on the right.
///
/// Nothing except the quantity control rebuilds when the cart changes. Only
/// the control listens to the cart, and only to this item's own quantity, so
/// tapping "+" on one row rebuilds that row's control and nothing else in the
/// list.
class MenuItemRow extends StatelessWidget {
  final MenuItem item;
  final MenuLayout layout;

  const MenuItemRow({super.key, required this.item, required this.layout});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // A sold-out row is muted as a whole. The name and price stay readable.
    final muted = item.isAvailable ? null : colors.onSurfaceVariant;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            16,
            MenuLayout.rowPaddingTop,
            16,
            MenuLayout.rowPaddingBottom,
          ),
          child: SizedBox(
            height: layout.contentHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ItemThumbnail(
                  url: item.thumbnailUrl,
                  size: MenuLayout.thumbnailSize,
                  dimmed: !item.isAvailable,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: layout.nameStyle.copyWith(color: muted),
                        maxLines: MenuLayout.nameLines,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // The row reserves two lines for the name. When the
                      // name needs only one, the description takes the
                      // spare line, so short names do not leave a gap.
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) => Align(
                            alignment: AlignmentDirectional.topStart,
                            child: Text(
                              item.description,
                              style: layout.descriptionStyle,
                              maxLines:
                                  constraints.maxHeight >=
                                      2 * layout.descriptionLineHeight
                                  ? 2
                                  : 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: MenuLayout.controlHeight,
                        child: Row(
                          children: [
                            Expanded(child: _price(muted)),
                            const SizedBox(width: 12),
                            if (item.isAvailable)
                              _QuantityControl(item: item)
                            else
                              const _SoldOutLabel(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: MenuLayout.dividerHeight, thickness: 1),
      ],
    );
  }

  // A price is never cut short: it shrinks to fit instead.
  Widget _price(Color? color) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Text(
        formatMoney(item.priceCents),
        style: layout.priceStyle.copyWith(color: color),
      ),
    );
  }
}

class _QuantityControl extends StatelessWidget {
  final MenuItem item;

  const _QuantityControl({required this.item});

  @override
  Widget build(BuildContext context) {
    // The selector returns this item's quantity and whether an order is
    // being sent. The control rebuilds only when one of those two changes.
    return BlocSelector<CartCubit, CartState, (int, bool)>(
      selector: (cart) => (cart.quantityOf(item.id), cart.isSubmitting),
      builder: (context, selected) {
        final (quantity, isSubmitting) = selected;
        final cart = context.read<CartCubit>();

        return QuantityStepper(
          itemName: item.name,
          quantity: quantity,
          onDecrement: isSubmitting ? null : () => cart.decrement(item.id),
          onIncrement: isSubmitting ? null : () => cart.add(item),
        );
      },
    );
  }
}

/// Availability is shown by exception: an item that can be ordered has a
/// "+" button, and one that cannot says so in words where the button was.
class _SoldOutLabel extends StatelessWidget {
  const _SoldOutLabel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // The label's text stops growing at 1.3 times, so it always fits beside
    // the price on a narrow phone and stays against the right edge.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      // Plain text, not a chip: an outline here would look like a button.
      child: Text(
        'Sold out',
        maxLines: 1,
        style: theme.textTheme.labelLarge!.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
