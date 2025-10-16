import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/engine/events/game_event.dart';

/// 猎人开枪事件 - 公开可见
class HunterShootEvent extends GameEvent {
  final int? dayNumber;
  final GamePhase? phase;

  HunterShootEvent({required GamePlayer target, this.dayNumber, this.phase})
    : super(
        id: 'hunter_shoot_${DateTime.now().millisecondsSinceEpoch}',
        target: target,
        visibility: ['hunter'],
      );

  @override
  String toString() {
    return 'HunterShootEvent(id: $id)';
  }
}
