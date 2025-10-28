import 'dart:async';
import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/driver/player_driver.dart';
import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/skill/game_skill.dart';
import 'package:werewolf_arena/engine/event/game_event.dart';

/// 人类玩家驱动器
///
/// 用于人类玩家的驱动器实现，通过UI等待人类输入决策
class HumanPlayerDriver implements PlayerDriver {
  @override
  Future<PlayerDriverResponse> request({
    required GamePlayer player,
    required GameState state,
    required GameSkill skill,
  }) async {
    return PlayerDriverResponse();
  }

  @override
  Future<String> updateMemory({
    required GamePlayer player,
    required String currentMemory,
    required List<GameEvent> currentPhaseEvents,
    required GameState state,
  }) async {
    // 人类玩家不需要自动更新记忆，直接返回当前记忆
    return currentMemory;
  }
}
