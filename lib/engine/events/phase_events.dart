import 'package:werewolf_arena/engine/events/game_event.dart';
import 'package:werewolf_arena/engine/events/player_events.dart' show DeadEvent;
import 'package:werewolf_arena/engine/domain/value_objects/game_event_type.dart';
import 'package:werewolf_arena/engine/domain/value_objects/event_visibility.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
import 'package:werewolf_arena/engine/game_state.dart';

/// 阶段转换事件 - 公开可见
class PhaseChangeEvent extends GameEvent {
  final GamePhase oldPhase;
  final GamePhase newPhase;
  final int dayNumber;

  PhaseChangeEvent({
    required this.oldPhase,
    required this.newPhase,
    required this.dayNumber,
  }) : super(
         eventId: 'phase_change_${DateTime.now().millisecondsSinceEpoch}',
         type: GameEventType.phaseChange,
         visibility: EventVisibility.public,
       );

  @override
  void execute(GameState state) {
    // 阶段转换由GameState处理
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'oldPhase': oldPhase.name,
      'newPhase': newPhase.name,
      'dayNumber': dayNumber,
    };
  }
}

/// 夜晚结果公告事件 - 公开可见
class NightResultEvent extends GameEvent {
  final List<DeadEvent> deathEvents;
  final bool isPeacefulNight;
  final int dayNumber;

  NightResultEvent({
    required this.deathEvents,
    required this.isPeacefulNight,
    required this.dayNumber,
  }) : super(
         eventId: 'night_result_${DateTime.now().millisecondsSinceEpoch}',
         type: GameEventType.dayBreak,
         visibility: EventVisibility.public,
       );

  @override
  void execute(GameState state) {
    // Night result announcement is handled by GameEngine
    // This event just provides information to players
  }
}

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
