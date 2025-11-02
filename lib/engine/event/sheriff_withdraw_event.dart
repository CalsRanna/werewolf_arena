import 'package:werewolf_arena/engine/event/game_event.dart';

/// 退水事件 - 上警玩家在竞选演讲后退出竞选
class SheriffWithdrawEvent extends GameEvent {
  final String playerName;

  SheriffWithdrawEvent({
    required this.playerName,
    required super.day,
  }) : super(visibility: ['public']);

  @override
  String toNarrative() {
    return '$playerName 选择退水，退出警长竞选';
  }
}
