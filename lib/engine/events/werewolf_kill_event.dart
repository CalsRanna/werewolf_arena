import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/engine/events/game_event.dart';

/// 狼人击杀事件 - 仅狼人可见
class WerewolfKillEvent extends GameEvent {
  final int? dayNumber;
  final GamePhase? phase;

  WerewolfKillEvent({required GamePlayer target, this.dayNumber, this.phase})
    : super(
        id: 'kill_${DateTime.now().millisecondsSinceEpoch}',
        target: target,
        visibility: ['werewolf', 'witch'],
      );
}
