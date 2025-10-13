import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
import 'package:werewolf_arena/engine/domain/value_objects/event_visibility.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_event_type.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/engine/domain/value_objects/speech_type.dart';
import 'package:werewolf_arena/engine/events/game_event.dart';
import 'package:werewolf_arena/engine/game_state.dart';

/// 发言事件 - 根据类型决定可见性
class SpeakEvent extends GameEvent {
  final GamePlayer speaker;
  final String message;
  final SpeechType speechType;
  final int? dayNumber;
  final GamePhase? phase;

  SpeakEvent({
    required this.speaker,
    required this.message,
    this.speechType = SpeechType.normal,
    this.dayNumber,
    this.phase,
  }) : super(
         eventId:
             'speak_${speaker.name}_${DateTime.now().millisecondsSinceEpoch}',
         type: GameEventType.playerAction,
         initiator: speaker,
         visibility: _getDefaultVisibility(speechType),
         visibleToGameRole: speechType == SpeechType.werewolfDiscussion
             ? 'werewolf'
             : null,
       );

  static EventVisibility _getDefaultVisibility(SpeechType speechType) {
    switch (speechType) {
      case SpeechType.normal:
      case SpeechType.lastWords:
        return EventVisibility.public;
      case SpeechType.werewolfDiscussion:
        return EventVisibility.roleSpecific;
    }
  }

  @override
  void execute(GameState state) {
    // 发言事件不需要执行特殊逻辑，只是记录
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'speaker': speaker.name,
      'message': message,
      'speechType': speechType.name,
      'dayNumber': dayNumber,
      'phase': phase?.name,
    };
  }
}
