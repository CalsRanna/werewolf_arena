import 'package:werewolf_arena/engine/event/game_event.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';

/// 发言顺序公告事件 - 公开可见
class OrderEvent extends GameEvent {
  final List<GamePlayer> players;

  OrderEvent({required this.players, required super.dayNumber})
    : super(
        visibility: [
          'villager',
          'werewolf',
          'seer',
          'witch',
          'hunter',
          'guard',
        ],
      );

  @override
  String toNarrative() {
    return '第$dayNumber天，发言顺序为${players.map((p) => p.name).join(", ")}';
  }
}
