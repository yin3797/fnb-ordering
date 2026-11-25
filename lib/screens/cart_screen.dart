import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubits/cart_cubit.dart';
import '../models/app_exception.dart';
import 'error_message.dart';
import 'format.dart';
import 'widgets/cart_line_tile.dart';
import 'widgets/message_view.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CartCubit, CartState>(
      // React once per result, not on every cart change.
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        // The order went through, so there is nothing left to show here.
        // The screen closes itself only while it is the one on top. If the
        // customer has already pressed back, this screen is still alive for
        // the length of its closing animation, and a second pop would close
        // the menu underneath.
        final isOnTop = ModalRoute.of(context)?.isCurrent ?? false;
        if (state.status is CheckoutSucceeded && isOnTop) {
          Navigator.of(context).pop();
        }
      },
      // Success empties the cart in the same moment this screen starts to
      // close. Skipping that one rebuild keeps the last frame on screen
      // during the closing animation, so "your cart is empty" never flashes.
      buildWhen: (previous, current) => current.status is! CheckoutSucceeded,
      builder: (context, state) {
        final cart = context.read<CartCubit>();

        return Scaffold(
          appBar: AppBar(title: const Text('Your cart')),
          // The total and the button sit in the bottom slot, so a snackbar
          // appears above them and never covers Place Order.
          bottomNavigationBar: state.isEmpty
              ? null
              : SafeArea(
                  child: _Centered(
                    child: _UntilArrived(
                      child: _OrderSummary(
                        state: state,
                        onPlaceOrder: cart.placeOrder,
                      ),
                    ),
                  ),
                ),
          body: SafeArea(
            bottom: false,
            child: _Centered(
              child: state.isEmpty
                  ? MessageView(
                      icon: Icons.shopping_bag_outlined,
                      message: 'Your cart is empty.',
                      actionLabel: 'Back to menu',
                      onAction: () => Navigator.of(context).pop(),
                    )
                  : _CartLines(state: state),
            ),
          ),
        );
      },
    );
  }
}

/// Keeps content at most 600 wide and centred on a large screen.
class _Centered extends StatelessWidget {
  final Widget child;

  const _Centered({required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: child,
      ),
    );
  }
}

/// Ignores taps until this screen has finished sliding in.
///
/// "Place order" sits exactly where the menu's "View cart" bar was. Without
/// this, the second tap of a double tap on the bar lands on the button while
/// the screen is still arriving, and an order is sent unseen.
class _UntilArrived extends StatelessWidget {
  final Widget child;

  const _UntilArrived({required this.child});

  @override
  Widget build(BuildContext context) {
    final arrival = ModalRoute.of(context)?.animation;
    if (arrival == null) return child;

    return AnimatedBuilder(
      animation: arrival,
      builder: (context, child) =>
          IgnorePointer(ignoring: !arrival.isCompleted, child: child),
      child: child,
    );
  }
}

class _CartLines extends StatelessWidget {
  final CartState state;

  const _CartLines({required this.state});

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartCubit>();
    final isSubmitting = state.isSubmitting;

    final colors = Theme.of(context).colorScheme;

    return ListView.separated(
      itemCount: state.lines.length,
      // Lets the list find a line again by its key after another line is
      // removed and the positions shift. Without it, a second swipe started
      // while the first line is still disappearing would be forgotten. Lines
      // and dividers alternate, so a line's place is twice its index.
      findChildIndexCallback: (key) {
        final index = state.lines.indexWhere(
          (line) => ValueKey(line.item.id) == key,
        );
        return index < 0 ? null : index * 2;
      },
      separatorBuilder: (context, index) =>
          const Divider(height: 1, thickness: 1),
      itemBuilder: (context, index) {
        final line = state.lines[index];
        final id = line.item.id;

        // Swiping a line away removes it at any quantity.
        return Dismissible(
          key: ValueKey(id),
          direction: DismissDirection.endToStart,
          // The line leaves the cart as soon as it has slid away, before its
          // closing animation. An order placed while it is still sliding
          // includes it, and the line springs back, so an order always
          // matches what is on screen.
          confirmDismiss: (_) async {
            if (cart.state.isSubmitting) return false;
            cart.remove(id);
            return true;
          },
          background: ColoredBox(
            color: colors.errorContainer,
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Icon(
                  Icons.delete_outline,
                  color: colors.onErrorContainer,
                  semanticLabel: 'Remove',
                ),
              ),
            ),
          ),
          // A swipe is invisible to a screen reader, so the same action is
          // offered there by name.
          child: Semantics(
            customSemanticsActions: isSubmitting
                ? null
                : {
                    CustomSemanticsAction(
                      label: 'Remove ${line.item.name}',
                    ): () =>
                        cart.remove(id),
                  },
            child: CartLineTile(
              line: line,
              onIncrement: isSubmitting ? null : () => cart.add(line.item),
              onDecrement: isSubmitting ? null : () => cart.decrement(id),
            ),
          ),
        );
      },
    );
  }
}

class _OrderSummary extends StatelessWidget {
  final CartState state;
  final VoidCallback onPlaceOrder;

  const _OrderSummary({required this.state, required this.onPlaceOrder});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = state.status;

    // A rejected order gets the same answer if sent again unchanged, so the
    // button only offers a retry when the failure was not a refusal.
    final canRetry =
        status is CheckoutFailed && status.error is! RequestRejectedException;

    // This bar is always on screen, so its text stops growing at 1.5 times.
    // Beyond that it would leave no room for the cart lines above it.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.5,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // An edge for cart lines to scroll under.
          const Divider(height: 1, thickness: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The label and the amount share a line when they fit, and the
                // amount drops to its own line when they do not.
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  children: [
                    Text(
                      'Total · ${formatItemCount(state.itemCount)}',
                      style: theme.textTheme.titleMedium,
                    ),
                    // A total is never cut short: it shrinks to fit instead.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        formatMoney(state.summary.totalCents),
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                // The reason stays on screen after a failed order. A snackbar
                // alone can be missed, for example if the app was in the
                // background when the result arrived.
                if (status is CheckoutFailed) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorMessage(status.error),
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                FilledButton(
                  // Disabling the button is a courtesy. The guard that stops a
                  // second order is in CartCubit.placeOrder.
                  onPressed: state.isSubmitting ? null : onPlaceOrder,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: state.isSubmitting
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              semanticsLabel: 'Placing order',
                            ),
                          )
                        : Text(canRetry ? 'Try again' : 'Place order'),
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
