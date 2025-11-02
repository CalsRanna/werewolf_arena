import 'package:werewolf_arena/engine/game_context.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/skill/game_skill.dart';

/// 推理上下文
///
/// 在推理链的各个步骤之间传递数据
/// 每个步骤可以读取之前步骤的输出，并添加自己的输出
class ReasoningContext {
  /// 当前玩家
  final GamePlayer player;

  /// 当前游戏状态
  final GameContext state;

  /// 当前技能
  final GameSkill skill;

  /// 步骤输出存储
  /// key: 步骤名称, value: 步骤输出
  final Map<String, dynamic> stepOutputs = {};

  /// 元数据：用于调试和日志
  final Map<String, dynamic> metadata = {};

  /// 完整的思考链（拼接所有步骤的reasoning）
  final StringBuffer completeThoughtChain = StringBuffer();

  ReasoningContext({
    required this.player,
    required this.state,
    required this.skill,
  });

  /// 设置步骤输出
  void setStepOutput(String stepName, dynamic output) {
    stepOutputs[stepName] = output;
    metadata['${stepName}_timestamp'] = DateTime.now().toIso8601String();
  }

  /// 记录步骤的token使用量
  void recordStepTokens(String stepName, int tokens) {
    metadata['${stepName}_tokens'] = tokens;

    // 累计总token
    final currentTotal = metadata['total_tokens'] as int? ?? 0;
    metadata['total_tokens'] = currentTotal + tokens;
  }

  /// 获取步骤输出
  T? getStepOutput<T>(String stepName) {
    return stepOutputs[stepName] as T?;
  }

  /// 追加思考内容
  void appendThought(String thought) {
    if (completeThoughtChain.isNotEmpty) {
      completeThoughtChain.write('\n\n');
    }
    completeThoughtChain.write(thought);
  }

  /// 设置元数据
  void setMetadata(String key, dynamic value) {
    metadata[key] = value;
  }

  /// 获取元数据
  T? getMetadata<T>(String key) {
    return metadata[key] as T?;
  }

  // ========== 便捷访问器（用于常用的步骤输出）==========

  /// 过滤后的上下文
  dynamic get filteredContext => getStepOutput('information_filter');

  /// 关键事实列表
  List<String>? get keyFacts => getStepOutput<List<String>>('fact_analysis');

  /// 身份推理结果
  Map<String, dynamic>? get identityInference =>
      getStepOutput<Map<String, dynamic>>('identity_inference');

  /// 选择的战术剧本
  dynamic get selectedPlaybook => getStepOutput('playbook_selection');

  /// 选择的角色面具
  dynamic get selectedMask => getStepOutput('mask_selection');

  /// 行动计划
  dynamic get actionPlan => getStepOutput('strategy_planning');

  /// 最终发言
  String? get finalSpeech => getStepOutput<String>('speech_generation');

  /// 目标玩家
  String? get targetPlayer => getStepOutput<String>('target_player');

  /// 发言质量评估
  dynamic get qualityAssessment => getStepOutput('self_reflection');
}
