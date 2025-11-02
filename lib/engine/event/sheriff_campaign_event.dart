import 'package:werewolf_arena/engine/event/game_event.dart';

/// 上警事件 - 玩家决定是否竞选警长
class SheriffCampaignEvent extends GameEvent {
  final String playerName;
  final bool isCampaigning;

  SheriffCampaignEvent({
    required this.playerName,
    required this.isCampaigning,
    required super.day,
  }) : super(visibility: ['public']);

  @override
  String toNarrative() {
    return isCampaigning
        ? '$playerName 选择上警竞选警长'
        : '$playerName 选择不上警';
  }
}
