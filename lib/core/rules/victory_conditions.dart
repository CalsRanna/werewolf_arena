import 'package:werewolf_arena/core/state/game_state.dart';
import 'package:werewolf_arena/services/logging/logger.dart';

/// 游戏胜利条件判定类
///
/// 负责根据当前游戏状态判定游戏是否结束以及哪个阵营获胜。
/// 这个类封装了所有与胜利条件相关的逻辑，遵循单一职责原则。
///
/// 胜利规则：
/// - 好人阵营获胜：所有狼人出局
/// - 狼人阵营获胜（屠神）：所有神职出局且狼人数量≥平民数量
/// - 狼人阵营获胜（屠民）：所有平民出局且狼人数量≥神职数量
///
/// 使用示例：
/// ```dart
/// final victoryConditions = VictoryConditions(gameState);
/// final winner = victoryConditions.check();
/// if (winner != null) {
///   print('$winner 获胜！');
/// }
/// ```
class VictoryConditions {
  final GameState _state;

  VictoryConditions(this._state);

  String? check() {
    // Good guys win: all werewolves are dead.
    if (_state.aliveWerewolves == 0) {
      LoggerUtil.instance.i('好人阵营获胜！所有狼人已出局\n');
      return '好人阵营';
    }

    // Werewolves win:
    // Condition 1: Kill all gods (if any gods exist in the game)
    final aliveGods = _state.gods.where((p) => p.isAlive).length;
    if (_state.gods.isNotEmpty && aliveGods == 0) {
      if (_state.aliveWerewolves >= _state.aliveVillagers) {
        LoggerUtil.instance.i('狼人阵营获胜！屠神成功（所有神职已出局，狼人占优势）\n');
        return '狼人阵营';
      }
    }

    // Condition 2: Kill all villagers (if any villagers exist in the game)
    if (_state.villagers.isNotEmpty && _state.aliveVillagers == 0) {
      if (_state.aliveWerewolves >= aliveGods) {
        LoggerUtil.instance.i('狼人阵营获胜！屠民成功（所有平民已出局，狼人占优势）\n');
        return '狼人阵营';
      }
    }
    
    // No winner yet
    return null;
  }
}
