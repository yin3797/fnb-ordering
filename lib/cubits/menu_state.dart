part of 'menu_cubit.dart';

/// The menu is in exactly one of three situations, and each carries
/// different data, so each is its own class.
sealed class MenuState extends Equatable {
  const MenuState();

  @override
  List<Object?> get props => [];
}

final class MenuLoading extends MenuState {
  const MenuLoading();
}

final class MenuLoaded extends MenuState {
  final List<MenuCategory> categories;

  const MenuLoaded(this.categories);

  @override
  List<Object?> get props => [categories];
}

final class MenuFailure extends MenuState {
  final AppException error;

  const MenuFailure(this.error);

  @override
  List<Object?> get props => [error];
}
