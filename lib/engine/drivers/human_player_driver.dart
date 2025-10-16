import 'dart:async';
import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
import 'package:werewolf_arena/engine/drivers/player_driver.dart';
import 'package:werewolf_arena/engine/game_state.dart';

/// 人类玩家驱动器
///
/// 用于人类玩家的驱动器实现，通过UI等待人类输入决策
class HumanPlayerDriver implements PlayerDriver {
  @override
  Future<PlayerDriverResponse> request({
    required GamePlayer player,
    required GameState state,
    required String skillPrompt,
  }) async {
    return PlayerDriverResponse();
  }
}
