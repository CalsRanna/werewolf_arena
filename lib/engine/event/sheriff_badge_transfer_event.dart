import 'package:werewolf_arena/engine/event/game_event.dart';

/// 警徽传递事件 - 警长死亡时传递警徽
class SheriffBadgeTransferEvent extends GameEvent {
  final String fromPlayerName;
  final String toPlayerName;

  SheriffBadgeTransferEvent({
    required this.fromPlayerName,
    required this.toPlayerName,
    required super.day,
  }) : super(visibility: ['public']);

  @override
  String toNarrative() {
    return '$fromPlayerName 将警徽传递给 $toPlayerName';
  }
}
