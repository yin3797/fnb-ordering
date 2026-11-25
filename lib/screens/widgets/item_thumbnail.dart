import 'package:flutter/material.dart';

/// A fixed-size picture on a soft tile, so nothing moves while images
/// arrive and every row has the same shape on its left edge.
class ItemThumbnail extends StatelessWidget {
  final String url;
  final double size;
  final bool dimmed;

  const ItemThumbnail({
    super.key,
    required this.url,
    required this.size,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final placeholder = Center(
      child: Icon(Icons.restaurant, color: colors.onSurfaceVariant),
    );

    return Opacity(
      opacity: dimmed ? 0.4 : 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ColoredBox(
          color: colors.surfaceContainerHighest,
          child: SizedBox.square(
            dimension: size,
            child: Padding(
              padding: const EdgeInsets.all(4),
              // No address means no picture; asking for one would only fail.
              child: url.isEmpty
                  ? placeholder
                  : Image.network(
                      url,
                      // The stand-in images are cut-outs, so they are shown whole.
                      // Real food photos would use BoxFit.cover and no padding.
                      fit: BoxFit.contain,
                      // Decoded at the size it is shown, not the size uploaded.
                      cacheWidth:
                          (size * MediaQuery.devicePixelRatioOf(context))
                              .round(),
                      excludeFromSemantics: true,
                      // Until the first frame is decoded there is nothing to
                      // draw, so the placeholder holds the space.
                      frameBuilder:
                          (context, child, frame, wasSynchronouslyLoaded) =>
                              frame == null && !wasSynchronouslyLoaded
                              ? placeholder
                              : child,
                      errorBuilder: (context, error, stackTrace) => placeholder,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
