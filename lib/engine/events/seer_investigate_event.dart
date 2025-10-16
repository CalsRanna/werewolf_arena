import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/engine/events/game_event.dart';

/// 预言家查验事件 - 仅预言家可见
class SeerInvestigateEvent extends GameEvent {
  final String investigationResult;
  final int? dayNumber;
  final GamePhase? phase;

  SeerInvestigateEvent({
    required GamePlayer target,
    required this.investigationResult,
    this.dayNumber,
    this.phase,
  }) : super(
         id: 'investigate_${DateTime.now().millisecondsSinceEpoch}',
         target: target,
         visibility: ['seer'],
       );
}
