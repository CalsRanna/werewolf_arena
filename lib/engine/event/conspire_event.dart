import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/event/game_event.dart';

/// 狼人讨论事件 - 仅狼人可见
class ConspireEvent extends GameEvent {
  final GamePlayer speaker;

  ConspireEvent({
    required this.speaker,
    required super.day,
    required super.message,
  }) : super(visibility: ['werewolf']);

  @override
  String toNarrative() {
    return '第$day天晚上，狼人讨论：$message';
  }
}
