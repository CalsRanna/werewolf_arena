import 'dart:async';

import 'package:werewolf_arena/engine/game.dart';
import 'package:werewolf_arena/engine/game_config.dart';
import 'package:werewolf_arena/engine/game_logger.dart';
import 'package:werewolf_arena/engine/game_observer.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/round/game_round_controller.dart';
import 'package:werewolf_arena/engine/scenario/game_scenario.dart';

/// 游戏引擎 - 负责创建Game实例
class GameEngine {
  final GameConfig config;
  final GameScenario scenario;
  final List<GamePlayer> players;
  final GameObserver? observer;
  final GameRoundController controller;

  GameEngine({
    required this.config,
    required this.scenario,
    required this.players,
    this.observer,
    required this.controller,
  });

  /// 创建一个新的游戏实例
  Future<Game> create() async {
    try {
      // 创建游戏实例
      final game = Game(
        gameId: 'game_${DateTime.now().millisecondsSinceEpoch}',
        scenario: scenario,
        players: players,
        controller: controller,
        observer: observer,
      );

      // 初始化游戏
      await game.ensureInitialized();

      return game;
    } catch (e) {
      GameLogger.instance.e('游戏创建失败: $e');
      rethrow;
    }
  }
}
