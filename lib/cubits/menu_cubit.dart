import 'dart:developer';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/app_exception.dart';
import '../models/menu_category.dart';
import '../repositories/menu_repository.dart';

part 'menu_state.dart';

class MenuCubit extends Cubit<MenuState> {
  final MenuRepository _repository;

  MenuCubit(this._repository) : super(const MenuLoading());

  // True while a request is running. The state cannot be used for this,
  // because the Cubit starts in MenuLoading before any request is made.
  bool _isLoading = false;

  /// Loads the menu. Retry calls this again.
  Future<void> load() async {
    if (_isLoading) return;
    _isLoading = true;

    emit(const MenuLoading());

    MenuState result;
    try {
      result = MenuLoaded(await _repository.fetchMenu());
    } on AppException catch (error) {
      result = MenuFailure(error);
    } catch (error, stackTrace) {
      // A repository should only throw an AppException. If one ever breaks
      // that promise, the customer still gets an error with Retry and not a
      // spinner that never ends.
      log(
        'Menu load failed',
        name: 'MenuCubit',
        error: error,
        stackTrace: stackTrace,
      );
      result = const MenuFailure(UnexpectedException());
    } finally {
      _isLoading = false;
    }

    // The Cubit may have been closed while the request was running.
    if (isClosed) return;
    emit(result);
  }
}
