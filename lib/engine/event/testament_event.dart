import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/event/game_event.dart';

/// 遗言事件 - 公开可见
class TestamentEvent extends GameEvent {
  final String message;
  final GamePlayer source;

  TestamentEvent(this.message, {required super.day, required this.source})
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
    return '第$day天，${source.name}发表遗言：$message';
  }
}
