import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/event/game_event.dart';

/// 玩家死亡事件 - 公开可见
class DeadEvent extends GameEvent {
  final GamePlayer target;

  DeadEvent({required super.day, required this.target})
    : super(visibility: const ['public']);

  @override
  String toNarrative() {
    return '第$day天，${target.name}死亡';
  }
}
