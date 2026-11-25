import 'package:flutter/material.dart';

/// The category name that stays pinned while its items scroll under it.
class CategoryHeader extends StatelessWidget {
  final String name;
  final double height;
  final TextStyle style;

  const CategoryHeader({
    super.key,
    required this.name,
    required this.height,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Container(
        height: height,
        // Opaque, so rows do not show through while they pass underneath,
        // and a shade apart from them, so it never reads as part of a row.
        color: Theme.of(context).colorScheme.surfaceContainer,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          name,
          style: style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
