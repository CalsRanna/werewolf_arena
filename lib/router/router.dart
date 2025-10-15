import 'package:auto_route/auto_route.dart';
import 'router.gr.dart';

@AutoRouterConfig()
class AppRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes {
    return [
      AutoRoute(page: BootstrapRoute.page),
      AutoRoute(page: HomeRoute.page),
      AutoRoute(page: GameRoute.page),
      AutoRoute(page: SettingsRoute.page),
      AutoRoute(page: LLMConfigRoute.page),
      AutoRoute(initial: true, page: DebugRoute.page),
    ];
  }
}

final router = AppRouter();
