import 'package:werewolf_arena/engine/event/game_event.dart';

/// 撕毁警徽事件 - 警长死亡时选择撕毁警徽
class SheriffTornEvent extends GameEvent {
  final String sheriffName;

  SheriffTornEvent({
    required this.sheriffName,
    required super.day,
  }) : super(visibility: ['public']);

  @override
  String toNarrative() {
    return '$sheriffName 选择撕毁警徽，本局不再有警长';
  }
}
