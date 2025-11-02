import 'package:werewolf_arena/engine/event/game_event.dart';

/// 警长投票事件 - 玩家投票选举警长
class SheriffVoteEvent extends GameEvent {
  final String voterName;
  final String targetName;

  SheriffVoteEvent({
    required this.voterName,
    required this.targetName,
    required super.day,
  }) : super(visibility: ['public']);

  @override
  String toNarrative() {
    return '$voterName 投票给 $targetName';
  }
}
