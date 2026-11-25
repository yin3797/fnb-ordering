import '../models/menu_category.dart';

abstract interface class MenuRepository {
  /// Returns the menu grouped by category.
  ///
  /// Throws an `AppException` on any failure.
  Future<List<MenuCategory>> fetchMenu();
}
