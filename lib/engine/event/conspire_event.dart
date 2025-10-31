import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/event/game_event.dart';

/// 狼人讨论事件 - 仅狼人可见
class ConspireEvent extends GameEvent {
  final String message;
  final GamePlayer source;

  ConspireEvent(this.message, {required super.day, required this.source})
    : super(visibility: ['werewolf']);

  @override
  String toNarrative() {
    return '第$day天晚上，狼人讨论环节，${source.name}：$message';
  }
}
