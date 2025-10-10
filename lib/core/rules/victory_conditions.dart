import 'package:werewolf_arena/core/state/game_state.dart';
import 'package:werewolf_arena/services/logging/logger.dart';

class VictoryConditions {
  final GameState _state;

  VictoryConditions(this._state);

  String? check() {
    // Good guys win: all werewolves are dead.
    if (_state.aliveWerewolves == 0) {
      LoggerUtil.instance.i('好人阵营获胜！所有狼人已出局\n');
      return 'Good';
    }

    // Werewolves win:
    // Condition 1: Kill all gods (if any gods exist in the game)
    final aliveGods = _state.gods.where((p) => p.isAlive).length;
    if (_state.gods.isNotEmpty && aliveGods == 0) {
      if (_state.aliveWerewolves >= _state.aliveVillagers) {
        LoggerUtil.instance.i('狼人阵营获胜！屠神成功（所有神职已出局，狼人占优势）\n');
        return 'Werewolves';
      }
    }

    // Condition 2: Kill all villagers (if any villagers exist in the game)
    if (_state.villagers.isNotEmpty && _state.aliveVillagers == 0) {
      if (_state.aliveWerewolves >= aliveGods) {
        LoggerUtil.instance.i('狼人阵营获胜！屠民成功（所有平民已出局，狼人占优势）\n');
        return 'Werewolves';
      }
    }
    
    // No winner yet
    return null;
  }
}
