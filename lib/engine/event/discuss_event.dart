import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/event/game_event.dart';

/// 发言事件 - 所有人可见
class DiscussEvent extends GameEvent {
  final GamePlayer speaker;

  DiscussEvent({
    required this.speaker,
    required super.dayNumber,
    required super.message,
  }) : super(
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
    return '第$dayNumber天，${speaker.name}发表了发言：$message';
  }
}
