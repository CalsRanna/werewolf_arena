import 'package:auto_route/auto_route.dart';
import 'router.gr.dart';

@AutoRouterConfig()
class AppRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes {
    return [
      AutoRoute(initial: true, page: BootstrapRoute.page),
      AutoRoute(page: HomeRoute.page),
      AutoRoute(page: GameRoute.page),
      AutoRoute(page: SettingsRoute.page),
    ];
  }
}

final router = AppRouter();