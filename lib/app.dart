import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;

import 'cubits/cart_cubit.dart';
import 'cubits/menu_cubit.dart';
import 'repositories/api_client.dart';
import 'repositories/checkout_repository.dart';
import 'repositories/dummy_json_menu_repository.dart';
import 'repositories/menu_repository.dart';
import 'repositories/simulated_checkout_repository.dart';
import 'screens/error_message.dart';
import 'screens/menu_screen.dart';

/// The one place where the app is wired together.
///
/// Repositories are created here and handed to the Cubits. Swapping the
/// simulated checkout for a real one is a change to this file only. A test
/// can pass its own repositories in.
class App extends StatelessWidget {
  final MenuRepository? menuRepository;
  final CheckoutRepository? checkoutRepository;

  const App({super.key, this.menuRepository, this.checkoutRepository});

  static const _seedColor = Colors.deepOrange;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<MenuRepository>(
          create: (_) =>
              menuRepository ??
              DummyJsonMenuRepository(ApiClient(http.Client())),
        ),
        RepositoryProvider<CheckoutRepository>(
          create: (_) =>
              checkoutRepository ?? const SimulatedCheckoutRepository(),
        ),
      ],
      // The Cubits sit above MaterialApp, so every screen pushed by the
      // Navigator can reach them, and the cart outlives any one screen.
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) =>
                MenuCubit(context.read<MenuRepository>())..load(),
          ),
          BlocProvider(
            create: (context) => CartCubit(context.read<CheckoutRepository>()),
          ),
        ],
        child: MaterialApp(
          title: 'F&B Ordering',
          debugShowCheckedModeBanner: false,
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          themeMode: ThemeMode.system,
          // The order result can arrive while either screen is showing. A
          // listener here sits above every screen but below MaterialApp's
          // own ScaffoldMessenger, so the message appears on whichever
          // screen the customer is looking at.
          builder: (context, child) => _OrderResultListener(child: child!),
          home: const MenuScreen(),
        ),
      ),
    );
  }

  ThemeData _theme(Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: brightness,
      ),
    );
  }
}

class _OrderResultListener extends StatelessWidget {
  final Widget child;

  const _OrderResultListener({required this.child});

  @override
  Widget build(BuildContext context) {
    return BlocListener<CartCubit, CartState>(
      // Fires once per change of status. A cart edit also changes the state,
      // but not the status, so it is ignored here.
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        final messenger = ScaffoldMessenger.of(context);

        final message = switch (state.status) {
          CheckoutSucceeded() => 'Order placed',
          CheckoutFailed(:final error) => errorMessage(error),
          CheckoutIdle() || CheckoutSubmitting() => null,
        };

        // A new attempt clears the last result's message. Editing the cart
        // does not, so "Order placed" is not cut short by the next add.
        if (state.status is CheckoutSubmitting || message != null) {
          messenger.hideCurrentSnackBar();
        }
        if (message == null) return;

        messenger.showSnackBar(
          SnackBar(
            // The message sits over the screen, so its text stops growing
            // at 1.5 times. Larger than that and it covers the app bar on a
            // small phone.
            content: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.5,
              child: Text(message),
            ),
          ),
        );
      },
      child: child,
    );
  }
}
