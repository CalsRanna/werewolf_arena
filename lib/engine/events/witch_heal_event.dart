import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/engine/events/game_event.dart';

/// 女巫救人事件 - 仅女巫可见
class WitchHealEvent extends GameEvent {
  final int? dayNumber;
  final GamePhase? phase;

  WitchHealEvent({required GamePlayer target, this.dayNumber, this.phase})
    : super(
        id: 'heal_${DateTime.now().millisecondsSinceEpoch}',
        target: target,
        visibility: ['witch', 'werewolf'],
      );
}
