import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
import 'package:werewolf_arena/engine/events/game_event.dart';

/// 猎人开枪事件 - 公开可见
class HunterShootEvent extends GameEvent {
  HunterShootEvent({required GamePlayer target})
    : super(
        id: 'hunter_shoot_${DateTime.now().millisecondsSinceEpoch}',
        target: target,
        visibility: ['hunter'],
      );

  @override
  String toNarrative() {
    return '第$dayNumber天${phase?.displayName}，猎人开枪击杀了${target?.name}';
  }

  @override
  String toString() {
    return 'HunterShootEvent($id)';
  }
}
