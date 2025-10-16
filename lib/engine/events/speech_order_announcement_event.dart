import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
import 'package:werewolf_arena/engine/events/game_event.dart';

/// 发言顺序公告事件 - 公开可见
class SpeechOrderAnnouncementEvent extends GameEvent {
  final List<GamePlayer> speakingOrder;
  final int dayNumber;
  final String direction; // "顺序" 或 "逆序"

  SpeechOrderAnnouncementEvent({
    required this.speakingOrder,
    required this.dayNumber,
    required this.direction,
  }) : super(
         eventId: 'speech_order_${DateTime.now().millisecondsSinceEpoch}',
         visibility: [
           'villager',
           'werewolf',
           'seer',
           'witch',
           'hunter',
           'guardian',
         ],
       );
}
