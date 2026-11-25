import 'package:equatable/equatable.dart';

class MenuItem extends Equatable {
  final int id;
  final String name;
  final String description;

  // Money is kept in cents so totals never pick up floating point error.
  final int priceCents;

  // False for a sold-out item. The repository decides this from what the
  // server sends; the app shows nothing finer than available or sold out.
  final bool isAvailable;
  final String thumbnailUrl;

  const MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.priceCents,
    required this.isAvailable,
    required this.thumbnailUrl,
  });

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    priceCents,
    isAvailable,
    thumbnailUrl,
  ];
}
