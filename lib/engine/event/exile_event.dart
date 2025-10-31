import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/event/game_event.dart';

/// 玩家被投票出局事件 - 公开可见
class ExileEvent extends GameEvent {
  final GamePlayer target;

  ExileEvent({required super.day, required this.target})
    : super(
        visibility: [
          'villager',
          'werewolf',
          'seer',
          'witch',
          'hunter',
          'guard',
        ],
      );

  @override
  String toNarrative() {
    return '第$day天，${target.name}被投票出局';
  }
}
