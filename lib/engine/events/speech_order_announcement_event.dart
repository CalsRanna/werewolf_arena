import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
import 'package:werewolf_arena/engine/events/game_event.dart';

/// 发言顺序公告事件 - 公开可见
class SpeechOrderAnnouncementEvent extends GameEvent {
  final List<GamePlayer> speakingOrder;
  final String direction; // "顺序" 或 "逆序"

  SpeechOrderAnnouncementEvent({
    required this.speakingOrder,
    required this.direction,
  }) : super(
         id: 'speech_order_${DateTime.now().millisecondsSinceEpoch}',
         visibility: [
           'villager',
           'werewolf',
           'seer',
           'witch',
           'hunter',
           'guardian',
         ],
       );

  @override
  String toNarrative() {
    return '第$dayNumber天${phase?.displayName}，发言顺序公告：${speakingOrder.map((p) => p.name).join(", ")}$direction';
  }

  @override
  String toString() {
    return 'SpeechOrderAnnouncementEvent($id)';
  }
}
