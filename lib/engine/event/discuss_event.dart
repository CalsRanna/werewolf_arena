import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/event/game_event.dart';

/// 发言事件 - 所有人可见
class DiscussEvent extends GameEvent {
  final String message;
  final GamePlayer source;

  DiscussEvent(this.message, {required super.day, required this.source})
    : super(visibility: const ['public']);

  @override
  String toNarrative() {
    return '第$day天，${source.name}：$message';
  }
}
