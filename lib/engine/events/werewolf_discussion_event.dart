import 'package:werewolf_arena/engine/domain/value_objects/speech_type.dart';
import 'package:werewolf_arena/engine/events/speak_event.dart';

/// 狼人讨论事件 - 仅狼人可见
class WerewolfDiscussionEvent extends SpeakEvent {
  WerewolfDiscussionEvent({
    required super.speaker,
    required super.message,
    super.dayNumber,
    super.phase,
  }) : super(speechType: SpeechType.werewolfDiscussion);
}
