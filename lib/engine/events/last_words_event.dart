import 'package:werewolf_arena/engine/domain/value_objects/speech_type.dart';
import 'package:werewolf_arena/engine/events/speak_event.dart';

/// 遗言事件 - 公开可见
class LastWordsEvent extends SpeakEvent {
  LastWordsEvent({
    required super.speaker,
    required super.message,
    super.dayNumber,
    super.phase,
  }) : super(speechType: SpeechType.lastWords);
}
