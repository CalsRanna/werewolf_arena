import 'package:werewolf_arena/engine/event/game_event.dart';

/// 竞选演讲事件 - 上警玩家发表竞选宣言
class SheriffSpeechEvent extends GameEvent {
  final String playerName;
  final String speech;

  SheriffSpeechEvent({
    required this.playerName,
    required this.speech,
    required super.day,
  }) : super(visibility: ['public']);

  @override
  String toNarrative() {
    return '$playerName 的竞选发言：$speech';
  }
}
