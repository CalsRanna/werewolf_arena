import 'package:openai_dart/openai_dart.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/game_context.dart';
import 'package:werewolf_arena/engine/game_config.dart';
import 'package:werewolf_arena/engine/game_logger.dart';
import 'package:werewolf_arena/engine/reasoning/staged/staged_reasoning_engine.dart';
import 'package:werewolf_arena/engine/reasoning/memory/working_memory.dart';
import 'package:werewolf_arena/engine/reasoning/chain/chain_reasoning_engine.dart';
import 'package:werewolf_arena/engine/reasoning/chain/step/action_rehearsal_step.dart';
import 'package:werewolf_arena/engine/reasoning/chain/step/fact_analysis_step.dart';
import 'package:werewolf_arena/engine/reasoning/chain/step/identity_inference_step.dart';
import 'package:werewolf_arena/engine/reasoning/chain/step/mask_selection_step.dart';
import 'package:werewolf_arena/engine/reasoning/chain/step/playbook_selection_step.dart';
import 'package:werewolf_arena/engine/reasoning/chain/step/self_reflection_step.dart';
import 'package:werewolf_arena/engine/reasoning/chain/step/speech_generation_step.dart';
import 'package:werewolf_arena/engine/reasoning/chain/step/strategy_planning_step.dart';
import 'package:werewolf_arena/engine/reasoning/chain/step/tactical_directive_step.dart';
import 'package:werewolf_arena/engine/reasoning/direct/direct_reasoning_engine.dart';
import 'package:werewolf_arena/engine/skill/game_skill.dart';
import 'package:werewolf_arena/engine/skill/skill_result.dart';

/// AI玩家实现
///
/// 使用推理引擎进行AI决策的玩家实现
/// 支持三种推理引擎：Chain（链式）、Staged（分阶段）、Direct（直接）
class AIPlayer extends GamePlayer {
  /// 推理引擎（Chain、Staged或Direct）
  final dynamic _reasoningEngine;

  /// 玩家智能配置
  final PlayerIntelligence intelligence;

  /// 工作记忆：存储结构化的游戏记忆
  /// 在推理过程中更新和使用
  WorkingMemory? workingMemory;

  /// 元数据：存储统计信息（如token使用量等）
  final Map<String, dynamic> metadata = {};

  AIPlayer({
    required super.id,
    required super.index,
    required this.intelligence,
    required super.role,
    required super.name,
    String? fastModelId,
    ReasoningEngineType engineType = ReasoningEngineType.staged,
  })  : _reasoningEngine = _createReasoningEngine(
          intelligence,
          fastModelId,
          engineType,
        ),
        super();

  /// 创建推理引擎
  static dynamic _createReasoningEngine(
    PlayerIntelligence intelligence,
    String? fastModelId,
    ReasoningEngineType engineType,
  ) {
    final client = OpenAIClient(
      apiKey: intelligence.apiKey,
      baseUrl: intelligence.baseUrl,
      headers: {
        'HTTP-Referer': 'https://github.com/CalsRanna/werewolf_arena',
        'X-Title': 'Werewolf Arena',
      },
    );

    final mainModel = intelligence.modelId;
    final fastModel = fastModelId ?? mainModel;

    switch (engineType) {
      case ReasoningEngineType.staged:
        // 分阶段推理引擎：3阶段（预处理 + 核心认知 + 后处理）
        return StagedReasoningEngine(
          client: client,
          powerfulModelId: mainModel,
          fastModelId: fastModel,
          enableVerboseLogging: true,
        );

      case ReasoningEngineType.direct:
        // 直接推理引擎：单次LLM调用
        return DirectReasoningEngine(
          client: client,
          modelId: mainModel,
          enableVerboseLogging: true,
        );

      case ReasoningEngineType.chain:
        // 链式推理引擎：10步推理链
        return ChainReasoningEngine(
          client: client,
          steps: [
            // 1. 事实分析 (使用快速模型)
            FactAnalysisStep(modelId: fastModel),

            // 2. 身份推理 (使用主模型，需要深度推理)
            IdentityInferenceStep(modelId: mainModel),

            // 3. 策略规划 (使用主模型，已优化社交网络整合)
            StrategyPlanningStep(modelId: mainModel),

            // 4. 战术指令生成 (使用快速模型)
            TacticalDirectiveStep(modelId: fastModel),

            // 5. 剧本选择 (使用快速模型)
            PlaybookSelectionStep(modelId: fastModel),

            // 6. 面具选择 (使用快速模型)
            MaskSelectionStep(modelId: fastModel),

            // 7. 发言生成 (使用主模型，已整合战术指令)
            SpeechGenerationStep(modelId: mainModel),

            // 8. 行动预演 (使用快速模型，预审查+重新生成机制)
            ActionRehearsalStep(modelId: fastModel),

            // 9. 自我反思 (保留用于长期记忆更新，但不再控制重新生成)
            SelfReflectionStep(
              modelId: fastModel,
              enableRegeneration: false, // 重新生成已由 ActionRehearsalStep 控制
            ),
          ],
          enableVerboseLogging: true,
        );
    }
  }

  @override
  String get formattedName => '[$name|${role.name}|${intelligence.modelId}]';

  @override
  Future<SkillResult> cast(GameSkill skill, GameContext context) async {
    try {
      // 使用推理引擎执行推理链
      final result = await _reasoningEngine.execute(
        player: this,
        state: context,
        skill: skill,
      );

      return SkillResult(
        caster: name,
        target: result.target,
        message: result.message,
        reasoning: result.reasoning,
      );
    } catch (e) {
      GameLogger.instance.e(
        '$name 推理引擎执行失败: $e\n'
        '技能类型: ${skill.runtimeType}',
      );
      return SkillResult(caster: name);
    }
  }
}
