import 'package:werewolf_arena/engine/player/game_player.dart';

/// 游戏事件基类
///
/// 所有游戏中的行为都通过事件来表达,事件驱动整个游戏流程。
/// 每个事件都有可见性规则,确保玩家只能看到他们应该看到的信息。
abstract class GameEvent {
  /// 事件唯一标识
  final String id;

  /// 事件目标
  final GamePlayer? target;
  final int? dayNumber;

  /// 事件可见性
  final List<String> visibility;

  GameEvent({
    required this.id,
    this.target,
    this.visibility = const [],
    this.dayNumber,
  });

  /// 检查事件对指定玩家是否可见
  ///
  /// 根据可见性规则判断玩家是否能看到此事件
  bool isVisibleTo(GamePlayer player) {
    return visibility.contains(player.role.id);
  }

  String toNarrative();

  @override
  String toString() {
    return 'GameEvent($id)';
  }
}
