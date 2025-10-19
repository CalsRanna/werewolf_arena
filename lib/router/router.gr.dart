// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:auto_route/auto_route.dart' as _i6;
import 'package:werewolf_arena/page/bootstrap/bootstrap_page.dart' as _i1;
import 'package:werewolf_arena/page/debug/debug_page.dart' as _i2;
import 'package:werewolf_arena/page/game/game_page.dart' as _i3;
import 'package:werewolf_arena/page/home/home_page.dart' as _i4;
import 'package:werewolf_arena/page/settings/settings_page.dart' as _i5;

/// generated route for
/// [_i1.BootstrapPage]
class BootstrapRoute extends _i6.PageRouteInfo<void> {
  const BootstrapRoute({List<_i6.PageRouteInfo>? children})
    : super(BootstrapRoute.name, initialChildren: children);

  static const String name = 'BootstrapRoute';

  static _i6.PageInfo page = _i6.PageInfo(
    name,
    builder: (data) {
      return const _i1.BootstrapPage();
    },
  );
}

/// generated route for
/// [_i2.DebugPage]
class DebugRoute extends _i6.PageRouteInfo<void> {
  const DebugRoute({List<_i6.PageRouteInfo>? children})
    : super(DebugRoute.name, initialChildren: children);

  static const String name = 'DebugRoute';

  static _i6.PageInfo page = _i6.PageInfo(
    name,
    builder: (data) {
      return const _i2.DebugPage();
    },
  );
}

/// generated route for
/// [_i3.GamePage]
class GameRoute extends _i6.PageRouteInfo<void> {
  const GameRoute({List<_i6.PageRouteInfo>? children})
    : super(GameRoute.name, initialChildren: children);

  static const String name = 'GameRoute';

  static _i6.PageInfo page = _i6.PageInfo(
    name,
    builder: (data) {
      return const _i3.GamePage();
    },
  );
}

/// generated route for
/// [_i4.HomePage]
class HomeRoute extends _i6.PageRouteInfo<void> {
  const HomeRoute({List<_i6.PageRouteInfo>? children})
    : super(HomeRoute.name, initialChildren: children);

  static const String name = 'HomeRoute';

  static _i6.PageInfo page = _i6.PageInfo(
    name,
    builder: (data) {
      return const _i4.HomePage();
    },
  );
}

/// generated route for
/// [_i5.SettingsPage]
class SettingsRoute extends _i6.PageRouteInfo<void> {
  const SettingsRoute({List<_i6.PageRouteInfo>? children})
    : super(SettingsRoute.name, initialChildren: children);

  static const String name = 'SettingsRoute';

  static _i6.PageInfo page = _i6.PageInfo(
    name,
    builder: (data) {
      return const _i5.SettingsPage();
    },
  );
}
