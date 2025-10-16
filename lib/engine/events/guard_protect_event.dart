import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/engine/events/game_event.dart';

/// 守卫保护事件 - 仅守卫可见
class GuardProtectEvent extends GameEvent {
  final int? dayNumber;
  final GamePhase? phase;

  GuardProtectEvent({required GamePlayer target, this.dayNumber, this.phase})
    : super(
        id: 'protect_${DateTime.now().millisecondsSinceEpoch}',
        target: target,
        visibility: ['guardian'],
      );
}
