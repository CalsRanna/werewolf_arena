import 'package:werewolf_arena/core/state/game_state.dart';
import 'package:werewolf_arena/core/domain/entities/player.dart';
import 'package:werewolf_arena/core/events/base/game_event.dart';
import 'package:werewolf_arena/core/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/core/domain/value_objects/game_event_type.dart';

/// 事件过滤服务
///
/// 负责过滤和管理游戏事件的可见性，包括：
/// - 获取玩家可见事件
/// - 按可见性过滤事件
/// - 按阶段过滤事件
/// - 按类型过滤事件
class EventFilterService {
  /// 获取玩家可见的事件
  ///
  /// [player] 目标玩家
  /// [eventHistory] 事件历史列表
  /// 返回该玩家可见的所有事件
  List<GameEvent> getEventsForPlayer(Player player, List<GameEvent> eventHistory) {
    return eventHistory.where((event) => event.isVisibleTo(player)).toList();
  }

  /// 按可见性过滤事件
  ///
  /// [events] 原始事件列表
  /// [player] 观察事件的玩家
  /// 返回该玩家可见的事件列表
  List<GameEvent> filterByVisibility(List<GameEvent> events, Player player) {
    return events.where((event) => event.isVisibleTo(player)).toList();
  }

  /// 按阶段过滤事件
  ///
  /// [events] 原始事件列表
  /// [phase] 目标阶段
  /// 返回发生在指定阶段的事件列表
  List<GameEvent> filterByPhase(List<GameEvent> events, GamePhase phase) {
    return events.where((event) {
      // 检查事件是否发生在指定阶段
      // 这里假设事件有阶段相关的属性，实际实现可能需要调整
      if (event.metadata.containsKey('phase')) {
        return event.metadata['phase'] == phase;
      }
      return false; // 如果没有阶段信息，默认不包含
    }).toList();
  }

  /// 按类型过滤事件
  ///
  /// [events] 原始事件列表
  /// [type] 目标事件类型
  /// 返回指定类型的事件列表
  List<GameEvent> filterByType(List<GameEvent> events, GameEventType type) {
    return events.where((event) => event.type == type).toList();
  }

  /// 获取最近的时间窗口内的事件
  ///
  /// [events] 原始事件列表
  /// [timeWindow] 时间窗口
  /// [player] 可选的观察玩家
  /// 返回最近时间窗口内的事件列表
  List<GameEvent> getRecentEvents(
    List<GameEvent> events,
    Duration timeWindow, {
    Player? player,
  }) {
    final cutoffTime = DateTime.now().subtract(timeWindow);

    return events.where((event) {
      final isInTimeWindow = event.timestamp.isAfter(cutoffTime);
      final isVisible = player == null || event.isVisibleTo(player);
      return isInTimeWindow && isVisible;
    }).toList();
  }

  /// 获取今天的白天事件
  ///
  /// [state] 游戏状态
  /// [player] 可选的观察玩家
  /// 返回今天白天阶段的事件
  List<GameEvent> getTodayDayEvents(GameState state, {Player? player}) {
    final todayEvents = state.eventHistory.where((event) {
      final isToday = event.metadata['dayNumber'] == state.dayNumber;
      final isDayPhase = event.metadata['phase'] == GamePhase.day;
      return isToday && isDayPhase;
    }).toList();

    if (player != null) {
      return filterByVisibility(todayEvents, player);
    }
    return todayEvents;
  }

  /// 获取今天的夜晚事件
  ///
  /// [state] 游戏状态
  /// [player] 可选的观察玩家
  /// 返回今天夜晚阶段的事件
  List<GameEvent> getTodayNightEvents(GameState state, {Player? player}) {
    final todayEvents = state.eventHistory.where((event) {
      final isToday = event.metadata['dayNumber'] == state.dayNumber;
      final isNightPhase = event.metadata['phase'] == GamePhase.night;
      return isToday && isNightPhase;
    }).toList();

    if (player != null) {
      return filterByVisibility(todayEvents, player);
    }
    return todayEvents;
  }

  /// 获取所有死亡事件
  ///
  /// [events] 原始事件列表
  /// [player] 可选的观察玩家
  /// 返回死亡事件列表
  List<GameEvent> getDeathEvents(List<GameEvent> events, {Player? player}) {
    final deathEvents = events.where((event) {
      return event.type.name == 'playerDeath';
    }).toList();

    if (player != null) {
      return filterByVisibility(deathEvents, player);
    }
    return deathEvents;
  }

  /// 获取所有发言事件
  ///
  /// [events] 原始事件列表
  /// [player] 可选的观察玩家
  /// 返回发言事件列表
  List<GameEvent> getSpeechEvents(List<GameEvent> events, {Player? player}) {
    final speechEvents = events.where((event) {
      return event.type.name == 'playerSpeech';
    }).toList();

    if (player != null) {
      return filterByVisibility(speechEvents, player);
    }
    return speechEvents;
  }

  /// 获取所有投票事件
  ///
  /// [events] 原始事件列表
  /// [player] 可选的观察玩家
  /// 返回投票事件列表
  List<GameEvent> getVotingEvents(List<GameEvent> events, {Player? player}) {
    final votingEvents = events.where((event) {
      return event.type.name == 'playerVote';
    }).toList();

    if (player != null) {
      return filterByVisibility(votingEvents, player);
    }
    return votingEvents;
  }

  /// 获取与特定玩家相关的事件
  ///
  /// [events] 原始事件列表
  /// [targetPlayer] 目标玩家
  /// [observerPlayer] 可选的观察玩家
  /// 返回与目标玩家相关的事件列表
  List<GameEvent> getEventsForPlayerTarget(
    List<GameEvent> events,
    Player targetPlayer, {
    Player? observerPlayer,
  }) {
    final relatedEvents = events.where((event) {
      // 检查事件是否与目标玩家相关
      return event.initiator == targetPlayer ||
             event.target == targetPlayer ||
             (event.metadata['players'] as List?)?.contains(targetPlayer) == true;
    }).toList();

    if (observerPlayer != null) {
      return filterByVisibility(relatedEvents, observerPlayer);
    }
    return relatedEvents;
  }

  /// 获取系统事件
  ///
  /// [events] 原始事件列表
  /// [player] 可选的观察玩家
  /// 返回系统事件列表
  List<GameEvent> getSystemEvents(List<GameEvent> events, {Player? player}) {
    final systemEvents = events.where((event) {
      return event.type.name.startsWith('system') ||
             event.type.name == 'gameStart' ||
             event.type.name == 'gameEnd' ||
             event.type.name == 'phaseChange';
    }).toList();

    if (player != null) {
      return filterByVisibility(systemEvents, player);
    }
    return systemEvents;
  }

  /// 统计事件类型分布
  ///
  /// [events] 事件列表
  /// 返回事件类型及其数量的映射
  Map<GameEventType, int> getEventTypeDistribution(List<GameEvent> events) {
    final distribution = <GameEventType, int>{};

    for (final event in events) {
      distribution[event.type] = (distribution[event.type] ?? 0) + 1;
    }

    return distribution;
  }

  /// 检查事件可见性规则
  ///
  /// [event] 要检查的事件
  /// [player] 观察玩家
  /// 返回事件是否应该对玩家可见
  bool checkEventVisibility(GameEvent event, Player player) {
    return event.isVisibleTo(player);
  }
}