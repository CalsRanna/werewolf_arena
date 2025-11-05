import 'package:openai_dart/openai_dart.dart';
import 'package:werewolf_arena/engine/game_context.dart';
import 'package:werewolf_arena/engine/game_logger.dart';
import 'package:werewolf_arena/engine/player/ai_player.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/reasoning/staged/core_cognition_stage.dart';
import 'package:werewolf_arena/engine/reasoning/staged/postprocessing_stage.dart';
import 'package:werewolf_arena/engine/reasoning/staged/preprocessing_stage.dart';
import 'package:werewolf_arena/engine/reasoning/reasoning_context.dart';
import 'package:werewolf_arena/engine/reasoning/reasoning_result.dart';
import 'package:werewolf_arena/engine/reasoning/memory/working_memory.dart';
import 'package:werewolf_arena/engine/skill/game_skill.dart';

/// 分阶段推理引擎
///
/// 采用三阶段架构：
/// 1. 预处理（Fast Model）：结构化数据整理
/// 2. 核心认知（Powerful Model）：单次统一推理
/// 3. 后处理（Fast Model）：安全检查
class StagedReasoningEngine {
  final OpenAIClient client;
  final String powerfulModelId;
  final String fastModelId;
  final bool enableVerboseLogging;

  late final PreprocessingStage _preprocessingStage;
  late final CoreCognitionStage _coreCognitionStage;
  late final PostprocessingStage _postprocessingStage;

  StagedReasoningEngine({
    required this.client,
    required this.powerfulModelId,
    required this.fastModelId,
    this.enableVerboseLogging = true,
  }) {
    _preprocessingStage = PreprocessingStage(
      client: client,
      fastModelId: fastModelId,
    );
    _coreCognitionStage = CoreCognitionStage(
      client: client,
      powerfulModelId: powerfulModelId,
    );
    _postprocessingStage = PostprocessingStage(
      client: client,
      fastModelId: fastModelId,
    );
  }

  /// 执行完整的推理流程
  Future<ReasoningResult> execute({
    required GamePlayer player,
    required GameContext state,
    required GameSkill skill,
  }) async {
    final startTime = DateTime.now();
    final stageMetrics = <String, Map<String, dynamic>>{};

    _log('=' * 60);
    _log('开始分阶段推理: ${player.name} (${player.role.name}) - ${skill.name}');
    _log('=' * 60);

    // 初始化统一的推理上下文
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

    try {
      // ========== 阶段一：预处理 ==========
      _log('\n[阶段1/3] 信息预处理');
      final stage1Start = DateTime.now();

      await _preprocessingStage.execute(context);

      final stage1Duration = DateTime.now().difference(stage1Start);
      stageMetrics['preprocessing'] = {
        'duration_ms': stage1Duration.inMilliseconds,
        'start_time': stage1Start.toIso8601String(),
      };
      _log('  耗时: ${stage1Duration.inMilliseconds}ms');

      // ========== 阶段二：核心认知 ==========
      _log('\n[阶段2/3] 核心认知');
      final stage2Start = DateTime.now();

      final cognitionResult = await _coreCognitionStage.execute(
        player: player,
        state: state,
        skill: skill,
        worldState: context.worldState!,
      );

      final stage2Duration = DateTime.now().difference(stage2Start);
      stageMetrics['core_cognition'] = {
        'duration_ms': stage2Duration.inMilliseconds,
        'start_time': stage2Start.toIso8601String(),
        'has_speech': cognitionResult.speech != null,
        'speech_length': cognitionResult.speech?.length ?? 0,
      };
      _log('  耗时: ${stage2Duration.inMilliseconds}ms');

      // 存储核心认知结果到context
      context.setStepOutput('cognition_result', cognitionResult);
      context.setStepOutput('speech_generation', cognitionResult.speech);
      context.setStepOutput('target_player', cognitionResult.target);
      context.appendThought(cognitionResult.analysis);

      // ========== 阶段三：后处理（可选）==========
      _log('\n[阶段3/3] 后处理');
      final stage3Start = DateTime.now();

      final teammates = <String>[];
      if (player.role.id == 'werewolf') {
        teammates.addAll(
          state.players
              .where((p) => p.role.id == 'werewolf' && p.id != player.id)
              .map((p) => p.name),
        );
      }

      final postprocessingResult = await _postprocessingStage.execute(
        playerName: player.name,
        role: player.role.name,
        faction: player.role.id == 'werewolf' ? '狼人' : '好人',
        teammates: teammates,
        cognitionResult: cognitionResult,
        skill: skill,
      );

      final stage3Duration = DateTime.now().difference(stage3Start);
      stageMetrics['postprocessing'] = {
        'duration_ms': stage3Duration.inMilliseconds,
        'start_time': stage3Start.toIso8601String(),
        'passed': postprocessingResult.passed,
        'report': postprocessingResult.report,
      };
      _log('  耗时: ${stage3Duration.inMilliseconds}ms');

      // 决定最终发言
      final finalSpeech =
          postprocessingResult.finalSpeech ?? cognitionResult.speech;

      // ========== 更新WorkingMemory ==========
      if (player is AIPlayer && cognitionResult.memoryUpdate != null) {
        _updatePlayerMemory(player, cognitionResult.memoryUpdate!);
      }

      // ========== 构建结果 ==========
      final endTime = DateTime.now();
      final totalDuration = endTime.difference(startTime);

      // 计算各阶段占比
      final stage1Percent =
          (stage1Duration.inMilliseconds / totalDuration.inMilliseconds * 100)
              .toStringAsFixed(1);
      final stage2Percent =
          (stage2Duration.inMilliseconds / totalDuration.inMilliseconds * 100)
              .toStringAsFixed(1);
      final stage3Percent =
          (stage3Duration.inMilliseconds / totalDuration.inMilliseconds * 100)
              .toStringAsFixed(1);

      _log('\n${'=' * 60}');
      _log('推理完成，总耗时: ${totalDuration.inMilliseconds}ms');
      _log(
        '  阶段1 (预处理):  ${stage1Duration.inMilliseconds}ms ($stage1Percent%)',
      );
      _log(
        '  阶段2 (核心认知): ${stage2Duration.inMilliseconds}ms ($stage2Percent%)',
      );
      _log(
        '  阶段3 (后处理):  ${stage3Duration.inMilliseconds}ms ($stage3Percent%)',
      );
      _log('=' * 60);

      return ReasoningResult(
        message: finalSpeech,
        reasoning: cognitionResult.analysis,
        target: cognitionResult.target,
        metadata: {
          'start_time': startTime.toIso8601String(),
          'end_time': endTime.toIso8601String(),
          'total_duration_ms': totalDuration.inMilliseconds,
          'engine_type': 'hybrid',
          'stages': 3,
          'stage_metrics': stageMetrics,
          'postprocessing_passed': postprocessingResult.passed,
          'postprocessing_report': postprocessingResult.report,
        },
      );
    } catch (e, stackTrace) {
      _logError('推理失败: $e\n$stackTrace');
      rethrow;
    }
  }

  /// 更新玩家记忆
  void _updatePlayerMemory(AIPlayer player, Map<String, dynamic> memoryUpdate) {
    try {
      // 获取或创建 WorkingMemory
      var memory = player.workingMemory;
      memory ??= WorkingMemory(
        secretKnowledge: SecretKnowledge(
          myRole: player.role.name,
          teammates: player.role.id == 'werewolf'
              ? player.metadata['teammates'] as List<String>? ?? []
              : [],
        ),
      );

      // 更新身份推测
      final identityInference =
          memoryUpdate['identity_inference'] as Map<String, dynamic>?;
      if (identityInference != null) {
        identityInference.forEach((playerName, data) {
          if (data is Map<String, dynamic>) {
            memory!.updateIdentityEstimate(
              playerName,
              IdentityEstimate(
                estimatedRole: data['estimated_role'] as String? ?? '未知',
                confidence: (data['confidence'] as num?)?.toInt() ?? 0,
                reasoning: data['reasoning'] as String? ?? '',
              ),
            );
          }
        });
      }

      // 更新关键事实
      final keyFacts = memoryUpdate['key_facts'] as List?;
      if (keyFacts != null) {
        for (var fact in keyFacts) {
          if (fact is Map<String, dynamic>) {
            memory.addKeyFact(
              KeyFact(
                description: fact['description'] as String? ?? '',
                importance: (fact['importance'] as num?)?.toInt() ?? 50,
                day: fact['day'] as int? ?? 1,
              ),
            );
          }
        }
      }

      // 更新核心矛盾
      final coreConflict = memoryUpdate['core_conflict'] as String?;
      if (coreConflict != null && coreConflict.isNotEmpty) {
        memory.coreConflict = coreConflict;
      }

      // 更新重点关注玩家
      final focusPlayers = memoryUpdate['focus_players'] as List?;
      if (focusPlayers != null) {
        memory.setFocusPlayers(focusPlayers.cast<String>());
      }

      // 保存更新后的记忆
      player.workingMemory = memory;

      _log(
        'WorkingMemory更新完成 - 身份推测: ${memory.identityEstimates.length}个, '
        '关键事实: ${memory.keyFacts.length}个',
      );
    } catch (e) {
      _logError('WorkingMemory更新失败: $e');
    }
  }

  void _log(String message) {
    if (enableVerboseLogging) {
      GameLogger.instance.d('[混合推理引擎] $message');
    }
  }

  void _logError(String message) {
    GameLogger.instance.e('[混合推理引擎] $message');
  }
}
