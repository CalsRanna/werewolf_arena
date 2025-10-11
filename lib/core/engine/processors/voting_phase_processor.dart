import 'package:werewolf_arena/core/state/game_state.dart';
import 'package:werewolf_arena/core/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/core/domain/entities/game_player.dart';
import 'package:werewolf_arena/core/domain/entities/ai_player.dart';
import 'package:werewolf_arena/core/domain/entities/game_role.dart';
import 'package:werewolf_arena/services/logging/logger.dart';
import 'package:werewolf_arena/services/logging/player_logger.dart';
import 'package:werewolf_arena/core/domain/value_objects/death_cause.dart';
import 'phase_processor.dart';

/// 投票阶段处理器
///
/// 负责处理游戏中的投票阶段，包括：
/// - 收集所有玩家的投票
/// - 解析投票结果
/// - 处理平票情况（PK阶段）
/// - 处理被投票出局的玩家遗言和技能
class VotingPhaseProcessor implements PhaseProcessor {
  @override
  GamePhase get supportedPhase => GamePhase.voting;

  @override
  Future<void> process(GameState state) async {
    LoggerUtil.instance.d('开始处理投票阶段 - 第${state.dayNumber}天');

    // 清空之前的投票
    state.votingState.clearVotes();

    // 收集投票
    await _collectVotes(state);

    // 解析投票结果
    await _resolveVoting(state);

    // 进入下一个夜晚
    state.dayNumber++;
    await state.changePhase(GamePhase.night);

    LoggerUtil.instance.d('投票阶段处理完成，进入第${state.dayNumber}夜');
  }

  /// 收集投票 - 所有玩家同时投票
  Future<void> _collectVotes(GameState state) async {
    LoggerUtil.instance.d('开始收集投票');

    final aliveGamePlayers = state.alivePlayers.where((p) => p.isAlive).toList();
    final voteFutures = <Future<void>>[];

    // 收集所有玩家的投票任务
    for (final voter in aliveGamePlayers) {
      if (voter is AIPlayer && voter.isAlive) {
        voteFutures.add(_processSingleVote(voter, state));
      }
    }

    // 等待所有玩家同时完成投票
    await Future.wait(voteFutures);

    LoggerUtil.instance.d('投票收集完成');
  }

  /// 处理单个玩家的投票
  Future<void> _processSingleVote(AIPlayer voter, GameState state) async {
    try {
      LoggerUtil.instance.d('处理玩家 ${voter.name} 的投票');

      // 更新玩家事件日志
      GamePlayerLogger.instance.updateGamePlayerEvents(voter, state);

      // 玩家独立决策
      await voter.processInformation(state);
      final target = await voter.chooseVoteTarget(state);

      if (target != null && target.isAlive) {
        final event = voter.createVoteEvent(target, state);
        if (event != null) {
          voter.executeEvent(event, state);
          LoggerUtil.instance.d('玩家 ${voter.name} 投票给 ${target.name}');
        } else {
          LoggerUtil.instance.debug('玩家 ${voter.name} 弃权或投票无效');
        }
      } else {
        LoggerUtil.instance.debug('玩家 ${voter.name} 弃权或投票无效');
      }
    } catch (e) {
      LoggerUtil.instance.e('玩家 ${voter.name} 投票失败: $e');
    }
  }

  /// 解析投票结果
  Future<void> _resolveVoting(GameState state) async {
    LoggerUtil.instance.d('开始解析投票结果');

    // 获取投票统计
    final voteResults = state.votingState.getVoteResults();
    final voteTarget = state.votingState.getVoteTarget(state.alivePlayers);
    final tiedGamePlayers = state.votingState.getTiedGamePlayers(state.alivePlayers);

    // 记录投票统计
    if (voteResults.isNotEmpty) {
      final sortedResults = voteResults.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      LoggerUtil.instance.d('投票结果：');
      for (final entry in sortedResults) {
        final player = state.getGamePlayerByName(entry.key);
        LoggerUtil.instance.d(
          '  ${player?.name ?? entry.key}: ${entry.value} 票',
        );
      }
    }

    if (voteTarget != null) {
      // 有明确的投票结果
      LoggerUtil.instance.d('投票结果：${voteTarget.name} 出局');

      // 处理遗言
      await _handleLastWords(voteTarget, state, 'vote');

      // 执行出局
      voteTarget.die(DeathCause.vote, state);
      LoggerUtil.instance.d('玩家 ${voteTarget.name} 被投票出局');

      // 处理猎人技能
      await _handleHunterDeath(voteTarget, state);
    } else {
      // 检查平票情况
      if (tiedGamePlayers.length > 1) {
        LoggerUtil.instance.d(
          '投票平票：${tiedGamePlayers.map((p) => p.name).join('、')}',
        );
        await _handlePKPhase(tiedGamePlayers, state);
      } else if (voteResults.isEmpty) {
        LoggerUtil.instance.d('没有玩家投票');
      } else {
        LoggerUtil.instance.d('投票无效，没有玩家出局');
      }
    }

    // 清空投票数据
    state.votingState.clearVotes();
  }

  /// 处理PK（平票）阶段 - 平票玩家发言，然后其他人投票
  Future<void> _handlePKPhase(List<GamePlayer> tiedGamePlayers, GameState state) async {
    LoggerUtil.instance.d(
      '开始PK阶段，平票玩家：${tiedGamePlayers.map((p) => p.name).join('、')}',
    );

    // 平票玩家依次发言
    for (int i = 0; i < tiedGamePlayers.length; i++) {
      final player = tiedGamePlayers[i];

      if (player is AIPlayer && player.isAlive) {
        try {
          LoggerUtil.instance.d('处理PK玩家 ${player.name} 的发言');

          // 更新玩家事件日志
          GamePlayerLogger.instance.updateGamePlayerEvents(player, state);

          await player.processInformation(state);
          final statement = await player.generateStatement(
            state,
            'PK发言：你在平票中，请为自己辩护，说服其他玩家不要投你出局。',
          );

          if (statement.isNotEmpty) {
            final event = player.createSpeakEvent(statement, state);
            if (event != null) {
              player.executeEvent(event, state);
              LoggerUtil.instance.d('PK玩家 ${player.name} 发言: $statement');
            } else {
              LoggerUtil.instance.debug('PK玩家 ${player.name} 无法创建发言事件');
            }
          } else {
            LoggerUtil.instance.debug('PK玩家 ${player.name} 未发言');
          }
        } catch (e) {
          LoggerUtil.instance.e('PK玩家 ${player.name} 发言失败: $e');
        }

        // PK玩家发言间隔
        if (i < tiedGamePlayers.length - 1) {
          await Future.delayed(const Duration(milliseconds: 1000));
        }
      }
    }

    LoggerUtil.instance.d('PK发言结束，其他玩家开始投票');

    // 清空之前的投票，准备PK投票
    state.votingState.clearVotes();

    // 其他玩家投票（不包括PK玩家自己）
    await _collectPKVotes(tiedGamePlayers, state);

    // 统计PK投票结果
    final pkResults = state.votingState.getVoteResults();
    if (pkResults.isNotEmpty) {
      LoggerUtil.instance.d('PK投票结果：');
      final sortedPkResults = pkResults.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final entry in sortedPkResults) {
        final player = state.getGamePlayerByName(entry.key);
        LoggerUtil.instance.d(
          '  ${player?.name ?? entry.key}: ${entry.value} 票',
        );
      }
    } else {
      LoggerUtil.instance.d('PK阶段没有投票');
    }

    // 得出PK结果
    final pkTarget = state.votingState.getVoteTarget(state.alivePlayers);
    if (pkTarget != null && tiedGamePlayers.contains(pkTarget)) {
      LoggerUtil.instance.d('PK结果：${pkTarget.name} 出局');

      // PK阶段被淘汰的玩家先留遗言
      await _handleLastWords(pkTarget, state, 'pk');

      pkTarget.die(DeathCause.vote, state);
      LoggerUtil.instance.d('PK玩家 ${pkTarget.name} 被投票出局');

      // 处理猎人技能
      await _handleHunterDeath(pkTarget, state);
    } else {
      LoggerUtil.instance.d('PK投票仍然平票或无效，没有人出局');
      if (pkResults.isEmpty) {
        LoggerUtil.instance.w('警告：PK阶段没有有效投票，可能存在问题');
      }
    }

    LoggerUtil.instance.d('PK阶段结束');
  }

  /// 收集PK投票（其他玩家投票，不包括PK候选人）
  Future<void> _collectPKVotes(
    List<GamePlayer> pkCandidates,
    GameState state,
  ) async {
    final aliveGamePlayers = state.alivePlayers.where((p) => p.isAlive).toList();

    // 排除PK候选人自己
    final voters = aliveGamePlayers
        .where((p) => !pkCandidates.contains(p))
        .toList();

    LoggerUtil.instance.d('收集PK投票，投票玩家：${voters.map((p) => p.name).join('、')}');

    final voteFutures = <Future<void>>[];

    for (final voter in voters) {
      if (voter is AIPlayer && voter.isAlive) {
        voteFutures.add(_processPKVote(voter, state, pkCandidates));
      }
    }

    await Future.wait(voteFutures);
  }

  /// 处理单个玩家的PK投票
  Future<void> _processPKVote(
    AIPlayer voter,
    GameState state,
    List<GamePlayer> pkCandidates,
  ) async {
    try {
      LoggerUtil.instance.d('处理玩家 ${voter.name} 的PK投票');

      // 更新玩家事件日志
      GamePlayerLogger.instance.updateGamePlayerEvents(voter, state);

      await voter.processInformation(state);
      final target = await voter.chooseVoteTarget(
        state,
        pkCandidates: pkCandidates,
      );

      if (target != null && target.isAlive && pkCandidates.contains(target)) {
        final event = voter.createVoteEvent(target, state);
        if (event != null) {
          voter.executeEvent(event, state);
          LoggerUtil.instance.d('玩家 ${voter.name} PK投票给 ${target.name}');
        } else {
          LoggerUtil.instance.debug('玩家 ${voter.name} PK投票弃权或无效');
        }
      } else {
        LoggerUtil.instance.debug('玩家 ${voter.name} PK投票弃权或无效');
      }
    } catch (e) {
      LoggerUtil.instance.e('玩家 ${voter.name} PK投票失败: $e');
    }
  }

  /// 处理玩家死亡（包括猎人技能）
  Future<void> _handleHunterDeath(GamePlayer hunter, GameState state) async {
    if (hunter.role is HunterGameRole) {
      final hunterGameRole = hunter.role as HunterGameRole;

      // 检查猎人是否可以开枪
      if (hunterGameRole.canShoot(state)) {
        LoggerUtil.instance.d('猎人 ${hunter.name} 可以开枪');

        if (hunter is AIPlayer) {
          // 简单AI：射击最可疑的玩家
          final suspiciousGamePlayers = hunter.getMostSuspiciousGamePlayers(state);
          if (suspiciousGamePlayers.isNotEmpty) {
            final target = suspiciousGamePlayers.first;
            final event = hunter.createHunterShootEvent(target, state);
            if (event != null) {
              hunter.executeEvent(event, state);
              LoggerUtil.instance.d('猎人 ${hunter.name} 开枪射击 ${target.name}');
            }
          } else {
            LoggerUtil.instance.d('猎人 ${hunter.name} 没有找到可疑目标');
          }
        }
      } else {
        LoggerUtil.instance.d('猎人 ${hunter.name} 不能开枪（可能已经开过枪）');
      }
    }
  }

  /// 处理玩家遗言
  Future<void> _handleLastWords(
    GamePlayer player,
    GameState state,
    String executionType,
  ) async {
    if (!player.isAlive) {
      return; // 玩家在留遗言时应该还活着
    }

    LoggerUtil.instance.d('处理玩家 ${player.name} 的遗言（${executionType}）');

    String lastWords = '';

    if (player is AIPlayer) {
      try {
        // 更新玩家知识
        GamePlayerLogger.instance.updateGamePlayerEvents(player, state);
        await player.processInformation(state);

        // 根据执行类型生成上下文
        String context;
        switch (executionType) {
          case 'vote':
            context = '遗言：你即将被全民投票出局，请留下你的最后一段话。你可以透露身份信息、分析场上形势、或给其他玩家重要提示。';
            break;
          case 'pk':
            context = '遗言：你在PK阶段被投票出局，请留下你的最后一段话。你可以透露身份信息、分析场上形势、或给其他玩家重要提示。';
            break;
          default:
            context = '遗言：你即将离开游戏，请留下你的最后一段话。';
        }

        LoggerUtil.instance.d('为玩家 ${player.name} 生成遗言...');
        lastWords = await player.generateStatement(state, context);

        if (lastWords.isEmpty) {
          lastWords = '我没有什么要说的了。'; // 默认回退
        }
      } catch (e) {
        LoggerUtil.instance.e('为玩家 ${player.name} 生成遗言失败: $e');
        lastWords = '我没有什么要说的了。'; // 错误时的回退
      }
    } else {
      // 人类玩家需要UI输入，这里使用占位符
      lastWords = '再见了，各位。';
    }

    // 创建并执行遗言事件
    final event = player.createLastWordsEvent(lastWords, state);
    if (event != null) {
      player.executeEvent(event, state);
      LoggerUtil.instance.d('玩家 ${player.name} 遗言: $lastWords');
    } else {
      LoggerUtil.instance.debug('无法为玩家 ${player.name} 创建遗言事件');
    }
  }
}
