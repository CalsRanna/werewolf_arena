import 'package:werewolf_arena/engine/event/game_event.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';

/// 狼人击杀事件 - 仅狼人可见
class KillEvent extends GameEvent {
  final GamePlayer target;

  KillEvent({required super.day, required this.target})
    : super(visibility: ['werewolf', 'witch']);

  @override
  String toNarrative() {
    return '第$day天，狼人选择击杀${target.name}';
  }
}
