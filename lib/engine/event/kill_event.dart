import 'package:werewolf_arena/engine/event/game_event.dart';

/// 狼人击杀事件 - 仅狼人可见
class KillEvent extends GameEvent {
  KillEvent({required super.target, required super.dayNumber})
    : super(visibility: ['werewolf', 'witch']);

  @override
  String toNarrative() {
    return '第$dayNumber天，狼人选择击杀：${target?.name}';
  }
}
