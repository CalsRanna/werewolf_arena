import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/event/game_event.dart';

/// 猎人开枪事件 - 公开可见
class ShootEvent extends GameEvent {
  ShootEvent({required GamePlayer target})
    : super(
        id: 'shoot_${DateTime.now().millisecondsSinceEpoch}',
        target: target,
        visibility: ['hunter'],
      );

  @override
  String toNarrative() {
    return '猎人选择击杀${target?.name}';
  }

  @override
  String toString() {
    return 'ShootEvent($id)';
  }
}
