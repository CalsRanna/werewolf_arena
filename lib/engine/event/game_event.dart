import 'package:werewolf_arena/engine/player/game_player.dart';

abstract class GameEvent {
  final String id;
  final GamePlayer? target;
  final String message;
  final int dayNumber;

  /// 事件可见性
  final List<String> visibility;

  GameEvent({
    this.target,
    this.visibility = const [],
    required this.dayNumber,
    this.message = '',
  }) : id = DateTime.now().millisecondsSinceEpoch.toString();

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
