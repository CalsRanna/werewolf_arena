import 'package:werewolf_arena/engine/event/game_event.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';

/// 预言家查验事件 - 仅预言家可见
class InvestigateEvent extends GameEvent {
  final GamePlayer target;

  InvestigateEvent({required super.day, required this.target})
    : super(visibility: ['seer']);

  @override
  String toNarrative() {
    return '第$day天，预言家选择查验${target.name}，他是${target.role.name}';
  }
}
