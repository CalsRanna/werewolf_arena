import 'package:openai_dart/openai_dart.dart';
import 'package:werewolf_arena/engine/driver/player_driver.dart';
import 'package:werewolf_arena/engine/game_config.dart';
import 'package:werewolf_arena/engine/game_engine_logger.dart';
import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/reasoning/ai_reasoning_engine.dart';
import 'package:werewolf_arena/engine/reasoning/legacy_reasoning_step.dart';
import 'package:werewolf_arena/engine/reasoning/steps/fact_analysis_step.dart';
import 'package:werewolf_arena/engine/reasoning/steps/identity_inference_step.dart';
import 'package:werewolf_arena/engine/reasoning/steps/mask_selection_step.dart';
import 'package:werewolf_arena/engine/reasoning/steps/playbook_selection_step.dart';
import 'package:werewolf_arena/engine/reasoning/steps/self_reflection_step.dart';
import 'package:werewolf_arena/engine/reasoning/steps/speech_generation_step.dart';
import 'package:werewolf_arena/engine/reasoning/steps/strategy_planning_step.dart';
import 'package:werewolf_arena/engine/skill/game_skill.dart';

/// AI玩家驱动器（重构版）
///
/// 使用推理引擎协调多步推理流程
/// 当前使用LegacyReasoningStep保持向后兼容
/// 后续会逐步迁移到多步推理链
class AIPlayerDriver implements PlayerDriver {
  /// 玩家智能配置
  final PlayerIntelligence intelligence;

  /// 最大重试次数
  final int maxRetries;

  /// 快速模型ID（用于简单推理任务的性能优化，可选）
  final String? fastModelId;

  /// OpenAI客户端
  late final OpenAIClient _client;

  /// 推理引擎
  late final AIReasoningEngine _reasoningEngine;

  /// 构造函数
  ///
  /// [intelligence] 玩家的AI配置，包含API密钥、模型ID等信息
  /// [maxRetries] 最大重试次数，默认为10
  /// [fastModelId] 用于简单推理任务的快速模型ID（如果为null，所有步骤使用主模型）
  /// [useMultiStepReasoning] 是否使用多步推理链（默认true），false则使用遗留单步推理
  AIPlayerDriver({
    required this.intelligence,
    this.maxRetries = 10,
    this.fastModelId,
    bool useMultiStepReasoning = true,
  }) {
    _client = OpenAIClient(
      apiKey: intelligence.apiKey,
      baseUrl: intelligence.baseUrl,
      headers: {
        'HTTP-Referer': 'https://github.com/CalsRanna/werewolf_arena',
        'X-Title': 'Werewolf Arena',
      },
    );

    // 初始化推理引擎
    if (useMultiStepReasoning) {
      // 确定快速模型和主模型
      final mainModel = intelligence.modelId;
      final fastModel = fastModelId ?? mainModel; // 如果没有配置快速模型，使用主模型

      // 使用多步推理链（Phase 4 - 7步推理）
      _reasoningEngine = AIReasoningEngine(
        client: _client,
        steps: [
          FactAnalysisStep(
            // 步骤1：事实分析（LLM）- 使用主模型
            modelId: mainModel,
          ),
          IdentityInferenceStep(
            // 步骤2：身份推理（LLM）- 使用主模型
            modelId: mainModel,
          ),
          StrategyPlanningStep(
            // 步骤3：策略规划（LLM）- 使用主模型
            modelId: mainModel,
          ),
          PlaybookSelectionStep(
            // 步骤4：剧本选择（LLM）- 使用快速模型（简单任务）
            modelId: fastModel,
          ),
          MaskSelectionStep(
            // 步骤5：面具选择（LLM）- 使用快速模型（简单任务）
            modelId: fastModel,
          ),
          SpeechGenerationStep(
            // 步骤6：发言生成（LLM）- 使用主模型
            modelId: mainModel,
          ),
          SelfReflectionStep(
            // 步骤7：自我反思（LLM）- 使用快速模型（简单任务）
            modelId: fastModel,
            enableRegeneration: false, // 暂时禁用重新生成
          ),
        ],
        enableVerboseLogging: true,
      );
    } else {
      // 使用遗留单步推理（Phase 1兼容模式）
      _reasoningEngine = AIReasoningEngine(
        client: _client,
        steps: [
          LegacyReasoningStep(
            maxRetries: maxRetries,
            modelId: intelligence.modelId,
          ),
        ],
        enableVerboseLogging: true,
      );
    }
  }

  @override
  Future<PlayerDriverResponse> request({
    required GamePlayer player,
    required GameState state,
    required GameSkill skill,
  }) async {
    try {
      // 使用推理引擎执行推理链
      final result = await _reasoningEngine.execute(
        player: player,
        state: state,
        skill: skill,
      );

      // 转换为PlayerDriverResponse格式
      return PlayerDriverResponse(
        message: result.message,
        reasoning: result.reasoning,
        target: result.target,
      );
    } catch (e) {
      GameEngineLogger.instance.e(
        '${player.name} 推理引擎执行失败: $e\n'
        '技能类型: ${skill.runtimeType}',
      );
      return PlayerDriverResponse();
    }
  }
}
