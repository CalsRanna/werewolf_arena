import 'package:werewolf_arena/engine/event/game_event.dart';

/// 游戏开始事件 - 公开可见
class GameStartEvent extends GameEvent {
  GameStartEvent() : super(visibility: const ['public']);

  @override
  String toNarrative() => '游戏开始';
}
