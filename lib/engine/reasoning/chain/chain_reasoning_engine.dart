import 'package:openai_dart/openai_dart.dart';
import 'package:werewolf_arena/engine/game_logger.dart';
import 'package:werewolf_arena/engine/game_context.dart';
import 'package:werewolf_arena/engine/reasoning/memory/working_memory.dart';
import 'package:werewolf_arena/engine/player/ai_player.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/reasoning/reasoning_context.dart';
import 'package:werewolf_arena/engine/reasoning/reasoning_result.dart';
import 'package:werewolf_arena/engine/reasoning/chain/step/reasoning_step.dart';
import 'package:werewolf_arena/engine/skill/game_skill.dart';

/// 链式推理引擎
///
/// 协调链式推理流程，管理各个推理步骤的执行
/// 采用10步推理链架构，串行执行各个推理步骤
class ChainReasoningEngine {
  /// OpenAI客户端
  final OpenAIClient client;

  /// 推理步骤链
  final List<ReasoningStep> steps;

  /// 是否启用详细日志
  final bool enableVerboseLogging;

  ChainReasoningEngine({
    required this.client,
    required this.steps,
    this.enableVerboseLogging = true,
  });

  /// 执行完整的推理链
  ///
  /// [player] 当前玩家
  /// [state] 游戏状态
  /// [skill] 当前技能
  ///
  /// 返回推理结果
  Future<ReasoningResult> execute({
    required GamePlayer player,
    required GameContext state,
    required GameSkill skill,
  }) async {
    final startTime = DateTime.now();

    // 初始化推理上下文
    final context = ReasoningContext(
      player: player,
      state: state,
      skill: skill,
    );

    context.setMetadata('start_time', startTime.toIso8601String());
    context.setMetadata('player_id', player.id);
    context.setMetadata('player_name', player.name);
    context.setMetadata('role', player.role.name);
    context.setMetadata('skill', skill.name);
    context.setMetadata('day', state.day);

    _log('开始执行推理链: ${player.name} (${player.role.name}) - ${skill.name}');
    _log('总共 ${steps.length} 个推理步骤');

    // 找到 speech_generation 和 action_rehearsal 步骤的索引
    int? speechStepIndex;
    int? rehearsalStepIndex;
    for (var i = 0; i < steps.length; i++) {
      if (steps[i].name == 'speech_generation') speechStepIndex = i;
      if (steps[i].name == 'action_rehearsal') rehearsalStepIndex = i;
    }

    // 依次执行各个推理步骤
    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];

      // 检查是否应该跳过此步骤
      if (step.shouldSkip(context)) {
        _log('跳过步骤 ${i + 1}/${steps.length}: ${step.name}');
        continue;
      }

      // 特殊处理: speech_generation 可能需要重新生成
      if (i == speechStepIndex &&
          speechStepIndex != null &&
          rehearsalStepIndex != null) {
        await _executeWithRegeneration(
          context,
          speechStep: steps[speechStepIndex],
          rehearsalStep: steps[rehearsalStepIndex],
          stepNumber: i + 1,
          totalSteps: steps.length,
        );
      } else if (i == rehearsalStepIndex) {
        // action_rehearsal 已经在上面的循环中执行了，跳过
        continue;
      } else {
        // 普通步骤执行
        await _executeStep(context, step, i + 1, steps.length);
      }
    }

    // 构建最终结果
    final endTime = DateTime.now();
    final totalDuration = endTime.difference(startTime);
    final totalTokens = context.getMetadata<int>('total_tokens') ?? 0;

    context.setMetadata('end_time', endTime.toIso8601String());
    context.setMetadata('total_duration_ms', totalDuration.inMilliseconds);

    _log('推理链完成，总耗时: ${totalDuration.inMilliseconds}ms, 总tokens: $totalTokens');

    // 持久化WorkingMemory回AIPlayer
    if (player is AIPlayer) {
      final workingMemory = context.getStepOutput<WorkingMemory>(
        'working_memory',
      );
      if (workingMemory != null) {
        player.workingMemory = workingMemory;
        _log('WorkingMemory已持久化到AIPlayer');
      }

      // 累计玩家的总token使用量
      final playerTotalTokens =
          (player.metadata['total_tokens_used'] as int? ?? 0) + totalTokens;
      player.metadata['total_tokens_used'] = playerTotalTokens;
      _log('玩家总token累计: $playerTotalTokens');
    }

    final result = ReasoningResult(
      message: context.finalSpeech,
      reasoning: context.completeThoughtChain.toString(),
      target: context.targetPlayer,
      metadata: Map.from(context.metadata),
    );

    if (enableVerboseLogging) {
      _log('\n${result.getDebugInfo()}');
    }

    return result;
  }

  /// 流式执行（可选功能��用于实时显示AI思考过程）
  ///
  /// 当前未实现，预留接口
  Stream<ReasoningProgress> executeStream({
    required GamePlayer player,
    required GameContext state,
    required GameSkill skill,
  }) async* {
    // 未来功能：实现流式执行
    throw UnimplementedError('流式执行暂未实现');
  }

  /// 执行单个步骤
  Future<void> _executeStep(
    ReasoningContext context,
    ReasoningStep step,
    int stepNumber,
    int totalSteps,
  ) async {
    final stepStartTime = DateTime.now();

    _log('执行步骤 $stepNumber/$totalSteps: ${step.name}');
    if (enableVerboseLogging) {
      _log('  描述: ${step.description}');
    }

    try {
      // 执行步骤
      await step.execute(context, client);

      final duration = DateTime.now().difference(stepStartTime);

      // 获取此步骤的token使用量
      final stepTokens = context.getMetadata<int>('${step.name}_tokens') ?? 0;
      final tokenInfo = stepTokens > 0 ? ', tokens: $stepTokens' : '';

      _log('  完成，耗时: ${duration.inMilliseconds}ms$tokenInfo');

      // 记录步骤耗时
      context.setMetadata(
        '${step.name}_duration_ms',
        duration.inMilliseconds,
      );
    } catch (e, stackTrace) {
      _logError('步骤 ${step.name} 执行失败: $e');
      if (enableVerboseLogging) {
        _logError('堆栈: $stackTrace');
      }

      // 记录错误但继续执行（某些步骤失败不应该导致整个流程崩溃）
      context.setMetadata('${step.name}_error', e.toString());
    }
  }

  /// 执行发言生成+行动预演的循环（支持重新生成）
  Future<void> _executeWithRegeneration(
    ReasoningContext context, {
    required ReasoningStep speechStep,
    required ReasoningStep rehearsalStep,
    required int stepNumber,
    required int totalSteps,
  }) async {
    const maxRegenerationAttempts = 3;
    int attempt = 0;

    while (attempt < maxRegenerationAttempts) {
      attempt++;

      if (attempt > 1) {
        _log('发言重新生成 (第 $attempt/$maxRegenerationAttempts 次尝试)');
      }

      // 1. 执行发言生成步骤
      await _executeStep(context, speechStep, stepNumber, totalSteps);

      // 2. 执行行动预演步骤
      final rehearsalNumber = stepNumber + 1;
      await _executeStep(context, rehearsalStep, rehearsalNumber, totalSteps);

      // 3. 检查是否需要重新生成
      final needsRegeneration =
          context.getStepOutput<bool>('needs_regeneration') ?? false;

      if (!needsRegeneration) {
        // 审查通过，跳出循环
        if (attempt > 1) {
          _log('发言重新生成成功，通过审查');
        }
        break;
      }

      // 4. 如果需要重新生成但已达最大尝试次数
      if (attempt >= maxRegenerationAttempts) {
        _logError(
          '发言重新生成失败：已达最大尝试次数 ($maxRegenerationAttempts)，'
          '使用最后一次生成结果',
        );
        break;
      }

      // 5. 清除上次的发言生成结果，准备重新生成
      context.setStepOutput('speech_generation', null);
      context.setStepOutput('target_player', null);
      context.setStepOutput('needs_regeneration', false);

      _log('审查未通过，准备重新生成发言...');
    }

    // 记录重新生成统计
    if (attempt > 1) {
      context.setMetadata('regeneration_attempts', attempt);
    }
  }

  void _log(String message) {
    if (enableVerboseLogging) {
      GameLogger.instance.d('[推理引擎] $message');
    }
  }

  void _logError(String message) {
    GameLogger.instance.e('[推理引擎] $message');
  }
}

/// 推理进度（用于流式执行）
class ReasoningProgress {
  final String stepName;
  final int currentStep;
  final int totalSteps;
  final String? intermediateOutput;

  const ReasoningProgress({
    required this.stepName,
    required this.currentStep,
    required this.totalSteps,
    this.intermediateOutput,
  });
}
