import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/menu_category.dart';

/// The sizes of the menu list, worked out once from the theme and the
/// phone's text-size setting.
///
/// Every row and header has a known height, so the scroll position of any
/// category can be calculated without building it. The tab row needs that to
/// jump to a category and to know which one is on screen. Heights grow with
/// the text-size setting, so large text gets a taller row and is not clipped.
class MenuLayout {
  static const thumbnailSize = 88.0;
  static const rowPaddingTop = 10.0;
  // Smaller than the top: the quantity control on the last line already has
  // 4 px of empty space around its visible shape.
  static const rowPaddingBottom = 6.0;
  static const headerPadding = 12.0;
  static const controlHeight = 48.0;
  static const dividerHeight = 1.0;
  static const nameLines = 2;
  // Height is reserved for one line of description, which keeps a row short
  // enough that about four fit on a tall phone. A row whose name fits on
  // one line shows two.
  static const descriptionLines = 1;

  final TextStyle headerStyle;
  final TextStyle nameStyle;
  final TextStyle descriptionStyle;
  final TextStyle priceStyle;

  final double descriptionLineHeight;
  final double headerExtent;
  final double contentHeight;
  final double rowExtent;

  const MenuLayout._({
    required this.headerStyle,
    required this.nameStyle,
    required this.descriptionStyle,
    required this.priceStyle,
    required this.descriptionLineHeight,
    required this.headerExtent,
    required this.contentHeight,
    required this.rowExtent,
  });

  factory MenuLayout.fromContext(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final scaler = MediaQuery.textScalerOf(context);

    final headerStyle = text.titleMedium!;
    final nameStyle = text.titleMedium!.copyWith(fontWeight: FontWeight.w600);
    final descriptionStyle = text.bodyMedium!.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final priceStyle = text.bodyLarge!;

    double line(TextStyle style) =>
        (scaler.scale(style.fontSize!) * (style.height ?? 1.2)).ceilToDouble();

    // The text column: name, description, then the price beside the button.
    final textColumnHeight =
        nameLines * line(nameStyle) +
        descriptionLines * line(descriptionStyle) +
        controlHeight;
    final contentHeight = math.max(thumbnailSize, textColumnHeight);

    return MenuLayout._(
      headerStyle: headerStyle,
      nameStyle: nameStyle,
      descriptionStyle: descriptionStyle,
      priceStyle: priceStyle,
      descriptionLineHeight: line(descriptionStyle),
      headerExtent: line(headerStyle) + 2 * headerPadding,
      contentHeight: contentHeight,
      rowExtent:
          rowPaddingTop + contentHeight + rowPaddingBottom + dividerHeight,
    );
  }

  double categoryExtent(MenuCategory category) =>
      headerExtent + category.items.length * rowExtent;

  /// The scroll position at which each category's header reaches the top.
  List<double> categoryOffsets(List<MenuCategory> categories) {
    final offsets = <double>[];
    var offset = 0.0;
    for (final category in categories) {
      offsets.add(offset);
      offset += categoryExtent(category);
    }
    return offsets;
  }

  /// The category whose header is at the top for a scroll position.
  static int categoryAt(List<double> offsets, double pixels) {
    var index = 0;
    for (var i = 0; i < offsets.length; i++) {
      if (offsets[i] <= pixels) index = i;
    }
    return index;
  }
}
