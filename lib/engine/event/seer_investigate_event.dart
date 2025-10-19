import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/event/game_event.dart';

/// 预言家查验事件 - 仅预言家可见
class SeerInvestigateEvent extends GameEvent {
  final String investigationResult;

  SeerInvestigateEvent({
    required GamePlayer target,
    required this.investigationResult,
  }) : super(
         id: 'investigate_${DateTime.now().millisecondsSinceEpoch}',
         target: target,
         visibility: ['seer'],
       );

  @override
  String toNarrative() {
    return '第$dayNumber天${phase?.displayName}，预言家查验了${target?.name}，结果是$investigationResult';
  }

  @override
  String toString() {
    return 'SeerInvestigateEvent($id)';
  }
}
