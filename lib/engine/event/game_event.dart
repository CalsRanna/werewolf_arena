import 'package:werewolf_arena/engine/player/game_player.dart';

abstract class GameEvent {
  final String id;
  final int day;
  final List<String> visibility;

  GameEvent({this.day = 0, this.visibility = const []})
    : id = DateTime.now().millisecondsSinceEpoch.toString();

  /// 判断事件是否对指定玩家可见
  ///
  /// 可见性规则：
  /// - 如果 visibility 包含 'public'，则所有玩家可见（公开事件）
  /// - 如果 visibility 为空，则不对玩家可见（内部事件，仅供观察者/调试）
  /// - 否则，检查玩家角色是否在 visibility 列表中
  bool isVisibleTo(GamePlayer player) {
    // 公开事件 - 所有人可见
    if (visibility.contains('public')) {
      return true;
    }

    // 空列表表示内部事件 - 不对玩家可见
    if (visibility.isEmpty) {
      return false;
    }

    // 检查玩家角色是否在可见列表中
    return visibility.contains(player.role.id);
  }

  String toNarrative();

  @override
  String toString() {
    return 'GameEvent($id)';
  }
}
