import 'package:openai_dart/openai_dart.dart';
import 'package:werewolf_arena/engine/game_engine_logger.dart';
import 'package:werewolf_arena/engine/memory/information_filter.dart';
import 'package:werewolf_arena/engine/memory/working_memory.dart';
import 'package:werewolf_arena/engine/player/ai_player.dart';
import 'package:werewolf_arena/engine/reasoning/reasoning_context.dart';
import 'package:werewolf_arena/engine/reasoning/reasoning_step.dart';

/// 事实分析步骤
///
/// CoT推理链的第一步：从大量信息中提取关键事实
/// 输出：关键事实列表和核心矛盾
class FactAnalysisStep extends ReasoningStep {
  final InformationFilter _filter = InformationFilter();

  @override
  String get name => 'fact_analysis';

  @override
  String get description => '分析当前局势，提取关键事实';

  @override
  Future<ReasoningContext> execute(
    ReasoningContext context,
    OpenAIClient client,
  ) async {
    GameEngineLogger.instance.d('[事实分析] 开始分析...');

    // 1. 使用信息过滤器提取关键信息
    final coreConflict = _filter.identifyCoreConflict(context.state, context.player);
    final keyFacts = _filter.extractKeyFacts(context.state, context.player, limit: 5);
    final focusPlayers = _filter.identifyFocusPlayers(context.state, context.player, limit: 3);

    // 2. 构建工作记忆（如果AI玩家还没有的话）
    WorkingMemory? workingMemory;
    if (context.player is AIPlayer) {
      final aiPlayer = context.player as AIPlayer;
      // TODO: 从AIPlayer中获取或创建WorkingMemory
      // 目前先创建临时的工作记忆
      workingMemory = _createTemporaryMemory(aiPlayer, context);
    }

    // 3. 将提取的信息存入上下文
    context.setStepOutput('core_conflict', coreConflict);
    context.setStepOutput('key_facts', keyFacts);
    context.setStepOutput('focus_players', focusPlayers);
    context.setStepOutput('working_memory', workingMemory);

    // 4. 记录到思考链
    final thought = StringBuffer();
    thought.writeln('[步骤1: 事实分析]');
    thought.writeln();
    thought.writeln('核心矛盾：$coreConflict');
    thought.writeln();
    thought.writeln('关键事实：');
    for (var i = 0; i < keyFacts.length; i++) {
      thought.writeln('${i + 1}. ${keyFacts[i].description}');
    }
    thought.writeln();
    thought.writeln('重点关注玩家：${focusPlayers.join(", ")}');

    context.appendThought(thought.toString());

    GameEngineLogger.instance.d(
      '[事实分析] 完成 - 核心矛盾: $coreConflict, '
      '关键事实: ${keyFacts.length}个, 关注玩家: ${focusPlayers.length}个',
    );

    return context;
  }

  /// 创建临时的工作记忆
  ///
  /// TODO: 后续应该持久化到AIPlayer中
  WorkingMemory _createTemporaryMemory(
    AIPlayer player,
    ReasoningContext context,
  ) {
    // 构建秘密知识
    final teammates = player.role.id == 'werewolf'
        ? context.state.werewolves
            .where((p) => p.id != player.id)
            .map((p) => p.name)
            .toList()
        : <String>[];

    final secretKnowledge = SecretKnowledge(
      myRole: player.role.name,
      teammates: teammates,
    );

    return WorkingMemory(
      secretKnowledge: secretKnowledge,
    );
  }
}
