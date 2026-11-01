import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/state/auth_state.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/example/presentation/pages/example_items_page.dart';
import '../../features/gateway/presentation/pages/gateway_home_page.dart';
import '../../features/gateway/presentation/pages/gateway_scanner_page.dart';
import '../../features/gateway/presentation/pages/gateway_scanner_setup_page.dart';
import '../../features/gateway/presentation/pages/gateway_portal_page.dart';
import '../../features/gateway/presentation/pages/gateway_companion_page.dart';
import '../../features/gateway/presentation/pages/gateway_about_page.dart';
import 'routes.dart';

export 'routes.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<AuthStatus>(AuthStatus.unknown);

  ref.listen<AuthStatus>(
    authControllerProvider.select((state) => state.status),
    (_, next) => refresh.value = next,
    fireImmediately: true,
  );

  final router = GoRouter(
    initialLocation: Routes.gateway,
    refreshListenable: refresh,
    redirect: (context, state) {
      final status = ref.read(authControllerProvider).status;
      final location = state.matchedLocation;
      final isGatewayRoute = location == Routes.gateway ||
          location.startsWith('${Routes.gateway}/');

      switch (status) {
        case AuthStatus.unknown:
          if (isGatewayRoute) return null;
          return location == Routes.splash ? null : Routes.splash;
        case AuthStatus.authenticated:
          return location == Routes.splash || location == Routes.login
              ? Routes.home
              : null;
        case AuthStatus.unauthenticated:
          if (isGatewayRoute) return null;
          return location == Routes.login ? null : Routes.login;
      }
    },
    routes: <RouteBase>[
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: Routes.home,
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: Routes.exampleItems,
        builder: (context, state) => const ExampleItemsPage(),
      ),
      GoRoute(
        path: Routes.gateway,
        builder: (context, state) => const GatewayHomePage(),
      ),
      GoRoute(
        path: Routes.gatewayScanner,
        builder: (context, state) => const GatewayScannerPage(),
      ),
      GoRoute(
        path: Routes.gatewayScannerSetup,
        builder: (context, state) => const GatewayScannerSetupPage(),
      ),
      GoRoute(
        path: Routes.gatewayPortal,
        builder: (context, state) => const GatewayPortalPage(),
      ),
      GoRoute(
        path: Routes.gatewayCompanion,
        builder: (context, state) => const GatewayCompanionPage(),
      ),
      GoRoute(
        path: Routes.gatewayAbout,
        builder: (context, state) => const GatewayAboutPage(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Route Error')),
      body: Center(
        child: Text('Route not found: ${state.uri}'),
      ),
    ),
  );

  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });

  return router;
});
