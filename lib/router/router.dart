import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'router.gr.dart';

@AutoRouterConfig()
class AppRouter extends RootStackRouter {
  AppRouter() : super(navigatorKey: globalKey);

  @override
  List<AutoRoute> get routes {
    return [
      AutoRoute(page: BootstrapRoute.page),
      AutoRoute(page: HomeRoute.page),
      AutoRoute(page: GameRoute.page),
      AutoRoute(page: SettingsRoute.page),
      AutoRoute(page: PlayerIntelligenceRoute.page),
      AutoRoute(page: PlayerIntelligenceDetailRoute.page),
      AutoRoute(initial: true, page: DebugRoute.page),
    ];
  }
}

final globalKey = GlobalKey<NavigatorState>();
final router = AppRouter();
