import 'package:werewolf_arena/engine/event/game_event.dart';

/// 平安夜事件 - 所有玩家可见
class PeacefulNightEvent extends GameEvent {
  PeacefulNightEvent() : super(visibility: const ['public']);

  @override
  String toNarrative() {
    return '昨晚是平安夜';
  }
}
