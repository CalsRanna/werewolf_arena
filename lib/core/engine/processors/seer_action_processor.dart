import 'package:werewolf_arena/core/state/game_state.dart';
import 'package:werewolf_arena/core/domain/entities/player.dart';
import 'package:werewolf_arena/services/logging/logger.dart';
import 'package:werewolf_arena/services/logging/player_logger.dart';
import 'action_processor.dart';

/// 预言家行动处理器
///
/// 负责处理预言家在夜晚阶段的行动，包括：
/// - 选择查验目标
/// - 验证查验合法性
/// - 执行查验行动并记录结果
class SeerActionProcessor implements ActionProcessor {
  @override
  Future<void> process(GameState state) async {
    LoggerUtil.instance.d('开始处理预言家行动');

    final seers = state.alivePlayers
        .where((p) => p.role.runtimeType.toString().contains('Seer'))
        .cast<Player>()
        .toList();

    if (seers.isEmpty) {
      LoggerUtil.instance.d('没有存活的预言家，跳过预言家行动');
      return;
    }

    LoggerUtil.instance.d('处理预言家行动，存活预言家数量：${seers.length}');

    // 依次处理每个预言家的行动
    for (int i = 0; i < seers.length; i++) {
      final seer = seers[i];
      await _processSeerAction(seer as AIPlayer, state, i < seers.length - 1);
    }

    LoggerUtil.instance.d('预言家行动处理完成');
  }

  /// 处理单个预言家的行动
  Future<void> _processSeerAction(
    AIPlayer seer,
    GameState state,
    bool hasMoreSeers,
  ) async {
    if (!seer.isAlive) {
      LoggerUtil.instance.w('尝试处理已死亡的预言家 ${seer.name} 的行动');
      return;
    }

    try {
      LoggerUtil.instance.d('处理预言家 ${seer.name} 的行动');

      // 更新玩家事件日志
      PlayerLogger.instance.updatePlayerEvents(seer, state);

      // 处理信息
      await seer.processInformation(state);

      // 选择查验目标
      final target = await seer.chooseNightTarget(state);

      if (target != null && target.isAlive) {
        // 验证查验行动的合法性
        if (_isValidSeerTarget(seer, target, state)) {
          final event = seer.createInvestigateEvent(target, state);
          if (event != null) {
            seer.executeEvent(event, state);
            LoggerUtil.instance.d(
              '预言家 ${seer.name} 选择查验 ${target.name}（结果：${target.role.isWerewolf ? '狼人' : '好人'}）',
            );
          } else {
            LoggerUtil.instance.debug('预言家 ${seer.name} 未能创建有效的查验事件');
          }
        } else {
          LoggerUtil.instance.debug(
            '预言家 ${seer.name} 选择的查验目标 ${target.name} 不合法',
          );
        }
      } else {
        LoggerUtil.instance.debug('预言家 ${seer.name} 未选择查验目标');
      }
    } catch (e) {
      LoggerUtil.instance.e('处理预言家 ${seer.name} 行动失败: $e');
    }

    // 多个预言家间的行动延迟
    if (hasMoreSeers) {
      await Future.delayed(const Duration(milliseconds: 1000));
    }
  }

  /// 验证查验目标的合法性
  bool _isValidSeerTarget(AIPlayer seer, Player target, GameState state) {
    // 检查基本条件：目标必须存活
    if (!target.isAlive) {
      LoggerUtil.instance.w('预言家 ${seer.name} 尝试查验已死亡的玩家 ${target.name}');
      return false;
    }

    // 检查是否查验自己
    if (target.name == seer.name) {
      LoggerUtil.instance.w('预言家 ${seer.name} 尝试查验自己');
      return false;
    }

    // 检查是否已经查验过该玩家
    if (_hasAlreadyInvestigated(seer, target, state)) {
      LoggerUtil.instance.d('预言家 ${seer.name} 已经查验过 ${target.name}');
      return false;
    }

    return true;
  }

  /// 检查是否已经查验过某个玩家
  bool _hasAlreadyInvestigated(AIPlayer seer, Player target, GameState state) {
    // 通过游戏状态元数据或事件历史查找查验记录
    final seerKey = 'seer_${seer.name}_investigated';
    final investigatedPlayers =
        state.metadata[seerKey] as Set<String>? ?? <String>{};

    return investigatedPlayers.contains(target.name);
  }

  /// 获取预言家的查验历史
  Map<String, bool> getInvestigationHistory(AIPlayer seer, GameState state) {
    final history = <String, bool>{};

    // 从元数据获取查验记录
    final seerKey = 'seer_${seer.name}_investigated';
    final investigatedPlayers =
        state.metadata[seerKey] as Set<String>? ?? <String>{};

    // 从事件历史中查找查验结果
    for (final playerName in investigatedPlayers) {
      final player = state.getPlayerByName(playerName);
      if (player != null) {
        // 查找对应的查验事件以获取结果
        final investigationResult = _getInvestigationResult(
          seer,
          player,
          state,
        );
        if (investigationResult != null) {
          history[playerName] = investigationResult;
        }
      }
    }

    final historyString = history.entries
        .map((entry) => '${entry.key}:${entry.value ? '狼人' : '好人'}')
        .join('、');
    LoggerUtil.instance.d('预言家 ${seer.name} 的查验历史：$historyString');
    return history;
  }

  /// 获取对特定玩家的查验结果
  bool? _getInvestigationResult(AIPlayer seer, Player target, GameState state) {
    // 在事件历史中查找查验事件
    final investigationEvents = state.eventHistory.where((event) {
      return event.type.name.contains('investigate') ||
          event.type.name.contains('seer') ||
          (event.initiator?.name == seer.name &&
              event.target?.name == target.name);
    }).toList();

    if (investigationEvents.isEmpty) {
      return null;
    }

    // 按时间排序，获取最新的查验事件
    investigationEvents.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // 根据事件信息推断查验结果
    // 这里需要根据实际的事件结构来获取结果
    // 暂时返回目标是否为狼人的信息
    return target.role.isWerewolf;
  }

  /// 获取可以查验的玩家列表
  List<Player> getValidSeerTargets(AIPlayer seer, GameState state) {
    final validTargets = <Player>[];

    for (final player in state.alivePlayers) {
      if (_isValidSeerTarget(seer, player, state)) {
        validTargets.add(player);
      }
    }

    LoggerUtil.instance.d(
      '预言家 ${seer.name} 的有效查验目标：${validTargets.map((p) => p.name).join('、')}',
    );
    return validTargets;
  }

  /// 获取未查验过的玩家列表
  List<Player> getUninvestigatedPlayers(AIPlayer seer, GameState state) {
    final uninvestigated = <Player>[];

    for (final player in state.alivePlayers) {
      if (!_hasAlreadyInvestigated(seer, player, state)) {
        uninvestigated.add(player);
      }
    }

    LoggerUtil.instance.d(
      '预言家 ${seer.name} 未查验过的玩家：${uninvestigated.map((p) => p.name).join('、')}',
    );
    return uninvestigated;
  }

  /// 清理预言家的查验历史记录（在游戏结束时调用）
  void clearInvestigationHistory(AIPlayer seer, GameState state) {
    final seerKey = 'seer_${seer.name}_investigated';
    state.metadata.remove(seerKey);

    LoggerUtil.instance.d('清理预言家 ${seer.name} 的查验历史记录');
  }

  /// 获取预言家的查验策略建议
  String getInvestigationAdvice(AIPlayer seer, GameState state) {
    final investigationHistory = getInvestigationHistory(seer, state);
    final uninvestigatedPlayers = getUninvestigatedPlayers(seer, state);

    if (uninvestigatedPlayers.isEmpty) {
      return '所有存活玩家都已查验过，可以考虑重新查验可疑目标。';
    }

    // 根据当前局势给出建议
    final knownWerewolves = investigationHistory.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    if (knownWerewolves.isEmpty) {
      return '还没有发现狼人，建议优先查验可疑或发言有问题的玩家。';
    } else {
      return '已发现狼人：${knownWerewolves.join('、')}，可以查验其他玩家以确认其身份。';
    }
  }

  /// 分析查验结果的可靠性
  double analyzeInvestigationReliability(AIPlayer seer, GameState state) {
    final totalInvestigations = getInvestigationHistory(seer, state).length;
    final alivePlayersCount = state.alivePlayers.length;

    if (totalInvestigations == 0) {
      return 0.0;
    }

    // 简单的可靠性计算：查验的玩家数量 / 存活玩家数量
    // 这可以根据实际游戏策略进行调整
    final reliability = totalInvestigations / alivePlayersCount;

    LoggerUtil.instance.d(
      '预言家 ${seer.name} 的查验可靠性：${(reliability * 100).toStringAsFixed(1)}%',
    );
    return reliability;
  }
}
