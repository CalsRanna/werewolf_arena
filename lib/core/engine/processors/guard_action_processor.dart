import 'package:werewolf_arena/core/state/game_state.dart';
import 'package:werewolf_arena/core/domain/entities/player.dart';
import 'package:werewolf_arena/services/logging/logger.dart';
import 'package:werewolf_arena/services/logging/player_logger.dart';
import 'action_processor.dart';

/// 守卫行动处理器
///
/// 负责处理守卫在夜晚阶段的行动，包括：
/// - 选择守护目标
/// - 验证守护合法性（不能连续两晚守护同一人）
/// - 执行守护行动
class GuardActionProcessor implements ActionProcessor {
  @override
  Future<void> process(GameState state) async {
    LoggerUtil.instance.d('开始处理守卫行动');

    final guards = state.alivePlayers
        .where((p) => p.role.runtimeType.toString().contains('Guard'))
        .cast<Player>()
        .toList();

    if (guards.isEmpty) {
      LoggerUtil.instance.d('没有存活的守卫，跳过守卫行动');
      return;
    }

    LoggerUtil.instance.d('处理守卫行动，存活守卫数量：${guards.length}');

    // 依次处理每个守卫的行动
    for (int i = 0; i < guards.length; i++) {
      final guard = guards[i];
      await _processGuardAction(
        guard as AIPlayer,
        state,
        i < guards.length - 1,
      );
    }

    LoggerUtil.instance.d('守卫行动处理完成');
  }

  /// 处理单个守卫的行动
  Future<void> _processGuardAction(
    AIPlayer guard,
    GameState state,
    bool hasMoreGuards,
  ) async {
    if (!guard.isAlive) {
      LoggerUtil.instance.w('尝试处理已死亡的守卫 ${guard.name} 的行动');
      return;
    }

    try {
      LoggerUtil.instance.d('处理守卫 ${guard.name} 的行动');

      // 更新玩家事件日志
      PlayerLogger.instance.updatePlayerEvents(guard, state);

      // 处理信息
      await guard.processInformation(state);

      // 选择守护目标
      final target = await guard.chooseNightTarget(state);

      if (target != null && target.isAlive) {
        // 验证守护行动的合法性
        if (_isValidGuardTarget(guard, target, state)) {
          final event = guard.createProtectEvent(target, state);
          if (event != null) {
            guard.executeEvent(event, state);
            LoggerUtil.instance.d('守卫 ${guard.name} 选择守护 ${target.name}');
          } else {
            LoggerUtil.instance.debug('守卫 ${guard.name} 未能创建有效的守护事件');
          }
        } else {
          LoggerUtil.instance.debug(
            '守卫 ${guard.name} 选择的守护目标 ${target.name} 不合法（可能是连续守护同一人）',
          );
        }
      } else {
        LoggerUtil.instance.debug('守卫 ${guard.name} 未选择守护目标');
      }
    } catch (e) {
      LoggerUtil.instance.e('处理守卫 ${guard.name} 行动失败: $e');
    }

    // 多个守卫间的行动延迟
    if (hasMoreGuards) {
      await Future.delayed(const Duration(milliseconds: 1000));
    }
  }

  /// 验证守护目标的合法性
  bool _isValidGuardTarget(AIPlayer guard, Player target, GameState state) {
    // 检查基本条件：目标必须存活
    if (!target.isAlive) {
      LoggerUtil.instance.w('守卫 ${guard.name} 尝试守护已死亡的玩家 ${target.name}');
      return false;
    }

    // 检查是否连续守护同一人
    if (_isGuardingSamePlayerConsecutively(guard, target, state)) {
      LoggerUtil.instance.d('守卫 ${guard.name} 尝试连续守护同一玩家 ${target.name}，不合法');
      return false;
    }

    return true;
  }

  /// 检查是否连续守护同一玩家
  bool _isGuardingSamePlayerConsecutively(
    AIPlayer guard,
    Player target,
    GameState state,
  ) {
    // 获取昨晚的守护记录
    final lastProtected = _getLastNightProtectedPlayer(guard, state);

    if (lastProtected != null && lastProtected.name == target.name) {
      LoggerUtil.instance.d(
        '守卫 ${guard.name} 昨晚守护了 ${lastProtected.name}，今晚不能连续守护同一人',
      );
      return true;
    }

    return false;
  }

  /// 获取昨晚被守护的玩家
  Player? _getLastNightProtectedPlayer(AIPlayer guard, GameState state) {
    // 通过游戏状态元数据或事件历史查找昨晚的守护记录
    // 这里我们使用GameState的metadata来存储守卫的守护历史

    // 检查是否有昨晚的守护记录
    final guardKey = 'guard_${guard.name}_last_protected';
    final lastProtectedName = state.metadata[guardKey] as String?;

    if (lastProtectedName != null) {
      // 查找对应的玩家
      final lastProtected = state.players
          .where((p) => p.name == lastProtectedName)
          .firstOrNull;

      if (lastProtected != null) {
        LoggerUtil.instance.d('守卫 ${guard.name} 昨晚守护了 ${lastProtected.name}');
        return lastProtected;
      }
    }

    // 如果没有元数据记录，也可以通过事件历史查找
    return _findLastProtectedFromHistory(guard, state);
  }

  /// 从事件历史中查找最后的守护记录
  Player? _findLastProtectedFromHistory(AIPlayer guard, GameState state) {
    // 查找昨晚的守护事件
    final lastNight = state.dayNumber - 1;

    // 查找守护相关的事件（这里需要根据实际的事件类型进行调整）
    final guardEvents = state.eventHistory.where((event) {
      // 检查是否是守护事件且在昨晚发生
      return event.type.name.contains('guard') ||
          event.type.name.contains('protect');
    }).toList();

    if (guardEvents.isEmpty) {
      return null;
    }

    // 按时间排序，获取最近的守护事件
    guardEvents.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final lastGuardEvent = guardEvents.first;

    // 检查是否是昨晚的事件（通过时间戳判断）
    final eventTime = lastGuardEvent.timestamp;
    final nightStartTime = DateTime.now().subtract(
      Duration(days: state.dayNumber - lastNight),
    );

    // 简化处理：如果事件时间接近昨晚，则认为是昨晚的事件
    if (eventTime.isAfter(nightStartTime.subtract(const Duration(hours: 12)))) {
      return lastGuardEvent.target;
    }

    return null;
  }

  /// 获取守卫的守护历史信息（用于AI决策）
  List<Player> getGuardHistory(AIPlayer guard, GameState state) {
    final history = <Player>[];

    // 从元数据获取最近的守护记录
    final guardKey = 'guard_${guard.name}_last_protected';
    final lastProtectedName = state.metadata[guardKey] as String?;

    if (lastProtectedName != null) {
      final lastProtected = state.players
          .where((p) => p.name == lastProtectedName)
          .firstOrNull;

      if (lastProtected != null) {
        history.add(lastProtected);
      }
    }

    // 这里可以扩展获取更多历史记录
    // 例如从事件历史中查找过去几晚的守护记录

    return history;
  }

  /// 获取可以守护的玩家列表（排除不能守护的目标）
  List<Player> getValidGuardTargets(AIPlayer guard, GameState state) {
    final validTargets = <Player>[];

    for (final player in state.alivePlayers) {
      if (_isValidGuardTarget(guard, player, state)) {
        validTargets.add(player);
      }
    }

    LoggerUtil.instance.d(
      '守卫 ${guard.name} 的有效守护目标：${validTargets.map((p) => p.name).join('、')}',
    );
    return validTargets;
  }

  /// 清理守卫的历史记录（在游戏结束时调用）
  void clearGuardHistory(AIPlayer guard, GameState state) {
    final guardKey = 'guard_${guard.name}_last_protected';
    state.metadata.remove(guardKey);

    LoggerUtil.instance.d('清理守卫 ${guard.name} 的守护历史记录');
  }
}
