import 'package:openai_dart/openai_dart.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/game_context.dart';
import 'package:werewolf_arena/engine/game_config.dart';
import 'package:werewolf_arena/engine/game_logger.dart';
import 'package:werewolf_arena/engine/reasoning/memory/working_memory.dart';
import 'package:werewolf_arena/engine/reasoning/reasoning_engine.dart';
import 'package:werewolf_arena/engine/reasoning/step/fact_analysis_step.dart';
import 'package:werewolf_arena/engine/reasoning/step/identity_inference_step.dart';
import 'package:werewolf_arena/engine/reasoning/step/mask_selection_step.dart';
import 'package:werewolf_arena/engine/reasoning/step/playbook_selection_step.dart';
import 'package:werewolf_arena/engine/reasoning/step/self_reflection_step.dart';
import 'package:werewolf_arena/engine/reasoning/step/speech_generation_step.dart';
import 'package:werewolf_arena/engine/reasoning/step/strategy_planning_step.dart';
import 'package:werewolf_arena/engine/skill/game_skill.dart';
import 'package:werewolf_arena/engine/skill/skill_result.dart';

/// AI玩家实现
///
/// 使用ReasoningEngine进行AI决策的玩家实现
class AIPlayer extends GamePlayer {
  /// 推理引擎
  final ReasoningEngine _reasoningEngine;

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
  })  : _reasoningEngine = _createReasoningEngine(intelligence, fastModelId),
        super();

  /// 创建推理引擎
  static ReasoningEngine _createReasoningEngine(
    PlayerIntelligence intelligence,
    String? fastModelId,
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

    return ReasoningEngine(
      client: client,
      steps: [
        FactAnalysisStep(modelId: fastModel),
        IdentityInferenceStep(modelId: mainModel),
        StrategyPlanningStep(modelId: mainModel),
        PlaybookSelectionStep(modelId: fastModel),
        MaskSelectionStep(modelId: fastModel),
        SpeechGenerationStep(modelId: mainModel),
        SelfReflectionStep(
          modelId: fastModel,
          enableRegeneration: false,
        ),
      ],
      enableVerboseLogging: true,
    );
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
