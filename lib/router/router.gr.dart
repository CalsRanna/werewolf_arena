// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:auto_route/auto_route.dart' as _i6;
import 'package:flutter/material.dart' as _i7;
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
class GameRoute extends _i6.PageRouteInfo<GameRouteArgs> {
  GameRoute({
    _i7.Key? key,
    String? scenarioId,
    List<_i6.PageRouteInfo>? children,
  }) : super(
         GameRoute.name,
         args: GameRouteArgs(key: key, scenarioId: scenarioId),
         rawPathParams: {'scenarioId': scenarioId},
         initialChildren: children,
       );

  static const String name = 'GameRoute';

  static _i6.PageInfo page = _i6.PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<GameRouteArgs>(
        orElse: () =>
            GameRouteArgs(scenarioId: pathParams.optString('scenarioId')),
      );
      return _i3.GamePage(key: args.key, scenarioId: args.scenarioId);
    },
  );
}

class GameRouteArgs {
  const GameRouteArgs({this.key, this.scenarioId});

  final _i7.Key? key;

  final String? scenarioId;

  @override
  String toString() {
    return 'GameRouteArgs{key: $key, scenarioId: $scenarioId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! GameRouteArgs) return false;
    return key == other.key && scenarioId == other.scenarioId;
  }

  @override
  int get hashCode => key.hashCode ^ scenarioId.hashCode;
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
