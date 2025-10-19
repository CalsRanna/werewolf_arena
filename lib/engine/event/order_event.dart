import 'package:werewolf_arena/engine/event/game_event.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';

/// 发言顺序公告事件 - 公开可见
class OrderEvent extends GameEvent {
  final List<GamePlayer> players;
  final String direction; // "顺序" 或 "逆序"

  OrderEvent({required this.players, required this.direction})
    : super(
        id: 'order_${DateTime.now().millisecondsSinceEpoch}',
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
    return '第$dayNumber天${phase?.displayName}，发言顺序公告：${players.map((p) => p.name).join(", ")}，$direction发言';
  }

  @override
  String toString() {
    return 'OrderEvent($id)';
  }
}
