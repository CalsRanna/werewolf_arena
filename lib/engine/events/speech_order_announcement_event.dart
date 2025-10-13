import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
import 'package:werewolf_arena/engine/domain/value_objects/event_visibility.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_event_type.dart';
import 'package:werewolf_arena/engine/events/game_event.dart';
import 'package:werewolf_arena/engine/game_state.dart';

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
         type: GameEventType.playerAction,
         visibility: EventVisibility.public,
       );

  @override
  void execute(GameState state) {
    // 发言顺序公告不需要修改游戏状态
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'speakingOrder': speakingOrder.map((p) => p.name).toList(),
      'dayNumber': dayNumber,
      'direction': direction,
    };
  }
}
