import 'package:werewolf_arena/engine/event/game_event.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/scenario/game_scenario.dart';

/// 游戏上下文 - 只读的游戏状态快照
///
/// 职责：
/// - 为玩家决策提供必要的只读信息
/// - 隔离玩家与完整游戏状态的直接访问
/// - 根据玩家角色过滤可见信息
///
/// 设计原则：
/// - 只读：所有属性都是final，不可修改
/// - 最小权限：只暴露玩家决策所需的信息
/// - 无副作用：所有方法都是查询方法，不改变状态
class GameContext {
  /// 当前天数
  final int day;

  /// 游戏场景配置
  final GameScenario scenario;

  /// 所有玩家列表（包括死亡玩家）
  final List<GamePlayer> allPlayers;

  /// 存活玩家列表
  final List<GamePlayer> alivePlayers;

  /// 该玩家可见的事件列表（已根据角色权限过滤）
  final List<GameEvent> visibleEvents;

  /// 女巫是否还能使用解药
  final bool canWitchHeal;

  /// 女巫是否还能使用毒药
  final bool canWitchPoison;

  /// 上一次守卫保护的玩家名称
  final String lastProtectedPlayer;

  GameContext({
    required this.day,
    required this.scenario,
    required this.allPlayers,
    required this.alivePlayers,
    required this.visibleEvents,
    required this.canWitchHeal,
    required this.canWitchPoison,
    required this.lastProtectedPlayer,
  });

  /// 根据玩家名称查找玩家
  GamePlayer? getPlayerByName(String playerName) {
    try {
      return allPlayers.firstWhere((p) => p.name == playerName);
    } catch (e) {
      return null;
    }
  }

  /// 获取指定天数的事件
  List<GameEvent> getEventsOfDay(int targetDay) {
    return visibleEvents.where((e) => e.day == targetDay).toList();
  }

  /// 获取最近N天的事件
  List<GameEvent> getRecentEvents(int days) {
    final startDay = day - days + 1;
    return visibleEvents
        .where((e) => e.day >= startDay && e.day <= day)
        .toList();
  }

  /// 获取所有事件
  List<GameEvent> getAllEvents() {
    return List.unmodifiable(visibleEvents);
  }

  /// 获取所有事件（别名，为了兼容性）
  List<GameEvent> get events => visibleEvents;

  /// 获取所有玩家（别名，为了兼容性）
  List<GamePlayer> get players => allPlayers;

  /// 获取死亡玩家列表
  List<GamePlayer> get deadPlayers {
    return allPlayers.where((p) => !p.isAlive).toList();
  }

  /// 获取神职玩家列表
  List<GamePlayer> get gods {
    return allPlayers
        .where((p) => p.role.id != 'werewolf' && p.role.id != 'villager')
        .toList();
  }

  /// 获取村民列表
  List<GamePlayer> get villagers {
    return allPlayers.where((p) => p.role.id == 'villager').toList();
  }

  /// 获取狼人列表
  List<GamePlayer> get werewolves {
    return allPlayers.where((p) => p.role.id == 'werewolf').toList();
  }

  /// 存活村民数量
  int get aliveVillagers => villagers.where((p) => p.isAlive).length;

  /// 存活狼人数量
  int get aliveWerewolves => werewolves.where((p) => p.isAlive).length;

  /// 存活神职数量
  int get aliveGods => gods.where((p) => p.isAlive).length;
}
