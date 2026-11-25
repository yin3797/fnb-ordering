import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubits/menu_cubit.dart';
import '../models/menu_category.dart';
import 'cart_screen.dart';
import 'error_message.dart';
import 'menu_layout.dart';
import 'widgets/cart_bar.dart';
import 'widgets/category_header.dart';
import 'widgets/menu_item_row.dart';
import 'widgets/message_view.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  static const _title = Text('Menu');

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MenuCubit, MenuState>(
      builder: (context, state) {
        final menu = context.read<MenuCubit>();

        // One case per state. MenuState is sealed, so leaving one out is a
        // compile error.
        return switch (state) {
          MenuLoading() => const _PlainPage(
            body: Center(child: CircularProgressIndicator()),
          ),
          MenuFailure(:final error) => _PlainPage(
            body: MessageView(
              icon: Icons.cloud_off,
              message: errorMessage(error),
              actionLabel: 'Try again',
              onAction: menu.load,
            ),
          ),
          // The tab row cannot be built with no categories, so an empty menu
          // gets its own message. The key gives a reloaded menu a fresh
          // state, because the tab count and the category offsets are fixed
          // when it is created.
          MenuLoaded(:final categories) =>
            categories.isEmpty
                ? _PlainPage(
                    body: MessageView(
                      icon: Icons.restaurant_menu,
                      message: 'Nothing is on the menu right now.',
                      actionLabel: 'Reload',
                      onAction: menu.load,
                    ),
                  )
                : _LoadedMenu(
                    key: ValueKey(categories),
                    categories: categories,
                  ),
        };
      },
    );
  }
}

/// The app bar with one thing under it: the spinner, an error or the
/// empty-menu message.
class _PlainPage extends StatelessWidget {
  final Widget body;

  const _PlainPage({required this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: MenuScreen._title),
      body: body,
    );
  }
}

/// The menu itself: a tab per category above one long list.
///
/// Which category is on screen is view state. It lives in the two controllers
/// here and not in a Cubit, and scrolling never rebuilds the list: the scroll
/// listener only moves the tab highlight.
class _LoadedMenu extends StatefulWidget {
  final List<MenuCategory> categories;

  const _LoadedMenu({super.key, required this.categories});

  @override
  State<_LoadedMenu> createState() => _LoadedMenuState();
}

class _LoadedMenuState extends State<_LoadedMenu>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(
    length: widget.categories.length,
    vsync: this,
  );
  final _scroll = ScrollController();

  late MenuLayout _layout;
  late List<double> _offsets;
  var _hasLayout = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_highlightCurrentCategory);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Runs again when the theme or the text-size setting changes.
    final previousOffsets = _hasLayout ? _offsets : null;
    final previousRowExtent = _hasLayout ? _layout.rowExtent : null;

    _layout = MenuLayout.fromContext(context);
    _offsets = _layout.categoryOffsets(widget.categories);
    _hasLayout = true;

    // A new text size changes every row height, so the old scroll position
    // now points at a different category. Go back to the start of the one
    // the customer was reading.
    if (previousOffsets != null &&
        previousRowExtent != _layout.rowExtent &&
        _scroll.hasClients) {
      final index = MenuLayout.categoryAt(previousOffsets, _scroll.offset);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) _jumpToCategory(index);
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _tabs.dispose();
    super.dispose();
  }

  void _highlightCurrentCategory() {
    final index = MenuLayout.categoryAt(_offsets, _scroll.offset);
    if (index != _tabs.index) _tabs.index = index;
  }

  // No animation: an animated scroll would pass through every category on
  // the way and flick the highlight across the tabs.
  void _jumpToCategory(int index) {
    _scroll.jumpTo(math.min(_offsets[index], _scroll.position.maxScrollExtent));
  }

  void _openCart() {
    // Ignored while the cart screen is still closing over this one. The
    // cart's button sits exactly where this bar is, so a second tap after a
    // placed order would otherwise fall through and reopen an empty cart.
    final covering = ModalRoute.of(context)?.secondaryAnimation;
    if (covering != null && !covering.isDismissed) return;

    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const CartScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final categories = widget.categories;

    return Scaffold(
      appBar: AppBar(
        title: MenuScreen._title,
        // One colour whether the list is scrolled or not. The tab row's
        // divider already separates the bar from the list.
        scrolledUnderElevation: 0,
        // The tab row has a fixed height, so its text stops growing at 1.3
        // times. Larger than that and the labels would be cut off. The list
        // below it has no such limit.
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kTextTabBarHeight),
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              onTap: _jumpToCategory,
              tabs: [
                for (final category in categories) Tab(text: category.name),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: CartBar(onPressed: _openCart),
      // Keeps rows clear of a notch in landscape. The cart bar below handles
      // the bottom edge.
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: CustomScrollView(
              controller: _scroll,
              slivers: [
                for (final category in categories)
                  SliverMainAxisGroup(
                    slivers: [
                      PinnedHeaderSliver(
                        child: CategoryHeader(
                          name: category.name,
                          height: _layout.headerExtent,
                          style: _layout.headerStyle,
                        ),
                      ),
                      SliverFixedExtentList.builder(
                        itemExtent: _layout.rowExtent,
                        itemCount: category.items.length,
                        itemBuilder: (context, index) => MenuItemRow(
                          item: category.items[index],
                          layout: _layout,
                        ),
                      ),
                    ],
                  ),
                // Empty space after the last category, so its header can reach
                // the top like every other one. It is sized during layout, so
                // it follows rotation and window resizing without rebuilding
                // the list.
                SliverLayoutBuilder(
                  builder: (context, constraints) => SliverToBoxAdapter(
                    child: SizedBox(
                      height: math.max(
                        0.0,
                        constraints.viewportMainAxisExtent -
                            _layout.categoryExtent(categories.last),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
