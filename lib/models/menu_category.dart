import 'package:equatable/equatable.dart';

import 'menu_item.dart';

class MenuCategory extends Equatable {
  final String id;
  final String name;
  final List<MenuItem> items;

  const MenuCategory({
    required this.id,
    required this.name,
    required this.items,
  });

  @override
  List<Object?> get props => [id, name, items];
}
