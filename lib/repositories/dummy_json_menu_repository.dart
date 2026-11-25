import 'dart:developer';

import '../models/app_exception.dart';
import '../models/menu_category.dart';
import '../models/menu_item.dart';
import 'api_client.dart';
import 'menu_repository.dart';
import 'parse_list.dart';

/// Loads the menu from DummyJSON, whose products stand in for menu items.
///
/// This class only knows the endpoint and how to translate its response.
/// Sending the request and sorting its failures is the [ApiClient]'s job.
class DummyJsonMenuRepository implements MenuRepository {
  final ApiClient _api;

  DummyJsonMenuRepository(this._api);

  // limit=0 returns every product. select keeps the payload to used fields.
  // id is listed too, so the app does not rely on it being sent unasked.
  static final _menuUri = Uri.https('dummyjson.com', '/products', {
    'limit': '0',
    'select':
        'id,title,description,category,price,stock,availabilityStatus,thumbnail',
  });

  @override
  Future<List<MenuCategory>> fetchMenu() async {
    final body = await _api.getJson(_menuUri);

    final rawProducts = body['products'];
    if (rawProducts is! List) {
      // The response has no product list, so the contract has changed.
      log('Menu response has no product list', name: 'DummyJsonMenuRepository');
      throw const UnexpectedException();
    }

    final products = parseList(rawProducts, _ProductDto.fromJson);
    return _groupByCategory(products);
  }

  // The API returns one flat list. Categories keep the order in which they
  // first appear. The lists are unmodifiable so nothing can change a loaded
  // menu in place.
  List<MenuCategory> _groupByCategory(List<_ProductDto> products) {
    final itemsByCategory = <String, List<MenuItem>>{};
    for (final product in products) {
      itemsByCategory
          .putIfAbsent(product.category, () => [])
          .add(product.toMenuItem());
    }

    return List.unmodifiable([
      for (final entry in itemsByCategory.entries)
        MenuCategory(
          id: entry.key,
          name: _displayName(entry.key),
          items: List.unmodifiable(entry.value),
        ),
    ]);
  }
}

// "mens-shirts" becomes "Mens Shirts".
String _displayName(String slug) {
  return slug
      .split('-')
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1))
      .join(' ');
}

/// One product as DummyJSON sends it, already checked. Private, so the API's
/// shape cannot leak past this file.
class _ProductDto {
  final int id;
  final String title;
  final String description;
  final String category;
  final int priceCents;
  final int stock;
  final String availabilityStatus;
  final String thumbnail;

  const _ProductDto({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.priceCents,
    required this.stock,
    required this.availabilityStatus,
    required this.thumbnail,
  });

  // In ringgit, as the API sends it. Far above any real menu price, and it
  // keeps a cart total far from integer overflow.
  static const _maxPrice = 1000000;

  // Everything that can fail happens here, so parseList can skip a bad
  // product: a missing field, a wrong type, an unusable value, or a price
  // that cannot be converted. Nothing after this can throw.

  factory _ProductDto.fromJson(Map<String, dynamic> json) {
    final title = json['title'] as String;
    final category = json['category'] as String;
    final price = json['price'] as num;

    // The right type is not enough. A negative price would lower a cart
    // total, an absurd one would overflow it, and a blank name or category
    // would draw an empty row or header.
    if (price < 0 ||
        price > _maxPrice ||
        title.trim().isEmpty ||
        _displayName(category).trim().isEmpty) {
      throw const FormatException('Product has an unusable value');
    }

    return _ProductDto(
      id: json['id'] as int,
      title: title,
      // A missing description, picture or status is not a reason to hide
      // something the customer could order. The stock count is required: it
      // decides whether the item can be ordered at all.
      description: json['description'] as String? ?? '',
      category: category,
      // The API sends 19.99; the app keeps 1999. round() is needed because
      // 19.99 * 100 comes out as 1998.9999... in floating point.
      priceCents: (price * 100).round(),
      stock: (json['stock'] as num).toInt(),
      availabilityStatus: json['availabilityStatus'] as String? ?? '',
      thumbnail: json['thumbnail'] as String? ?? '',
    );
  }

  MenuItem toMenuItem() {
    return MenuItem(
      id: id,
      name: title,
      description: description,
      priceCents: priceCents,
      isAvailable: _isAvailable,
      thumbnailUrl: thumbnail,
    );
  }

  // Nothing left means sold out, whatever the status text says. With stock
  // left, the server can still mark an item out of stock. The API also sends
  // "Low Stock", which the app does not show: a menu item is available or
  // sold out.
  bool get _isAvailable =>
      stock > 0 && availabilityStatus.trim().toLowerCase() != 'out of stock';
}
