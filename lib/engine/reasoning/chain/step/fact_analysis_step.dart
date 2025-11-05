import 'package:openai_dart/openai_dart.dart';
import 'package:werewolf_arena/engine/game_logger.dart';
import 'package:werewolf_arena/engine/reasoning/memory/working_memory.dart';
import 'package:werewolf_arena/engine/player/ai_player.dart';
import 'package:werewolf_arena/engine/reasoning/reasoning_context.dart';
import 'package:werewolf_arena/engine/reasoning/chain/step/reasoning_step.dart';

/// 事实分析步骤（LLM版本）
///
/// CoT推理链的第一步：使用LLM从大量信息中提取关键事实
/// 输出：关键事实列表、核心矛盾、重点关注玩家
class FactAnalysisStep extends ReasoningStep {
  final String modelId;

  FactAnalysisStep({required this.modelId});

  @override
  String get name => 'fact_analysis';

  @override
  String get description => '分析当前局势，提取关键事实';

  @override
  Future<ReasoningContext> execute(
    ReasoningContext context,
    OpenAIClient client,
  ) async {
    GameLogger.instance.d('[事实分析] 开始分析...');

    // 1. 获取或创建工作记忆
    WorkingMemory? workingMemory;
    if (context.player is AIPlayer) {
      final aiPlayer = context.player as AIPlayer;
      workingMemory =
          aiPlayer.workingMemory ?? _createInitialMemory(aiPlayer, context);
      aiPlayer.workingMemory = workingMemory;
    }

    // 2. 构建Prompt并调用LLM（带重试）
    try {
      final systemPrompt = _buildSystemPrompt();
      final userPrompt = _buildUserPrompt(context, workingMemory);

      final response = await request(
        client: client,
        modelId: modelId,
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        context: context,
      );

      // 解析关键事实
      final keyFactsList = response['key_facts'] as List? ?? [];
      final keyFacts = keyFactsList.map((factJson) {
        final factMap = factJson as Map<String, dynamic>;
        return KeyFact(
          description: factMap['description'] as String? ?? '未知事实',
          importance: (factMap['importance'] as num?)?.toInt() ?? 5,
          day: context.state.day,
        );
      }).toList();

      // 解析关注玩家
      final focusPlayersList = response['focus_players'] as List? ?? [];
      final focusPlayers = focusPlayersList
          .map((p) => p.toString())
          .where((p) => p.isNotEmpty)
          .toList();

      // 4. 存入上下文
      context.setStepOutput('core_conflict', response['core_conflict']);
      context.setStepOutput('key_facts', keyFacts);
      context.setStepOutput('focus_players', focusPlayers);
      context.setStepOutput('working_memory', workingMemory);

      // 5. 记录到思考链
      final thought = StringBuffer();
      thought.writeln('[步骤1: 事实分析]');
      thought.writeln();
      thought.writeln('核心矛盾：${response['core_conflict']}');
      thought.writeln();
      thought.writeln('关键事实：');
      for (var i = 0; i < keyFacts.length; i++) {
        thought.writeln('${i + 1}. ${keyFacts[i].description}');
      }
      thought.writeln();
      thought.writeln('重点关注玩家：${focusPlayers.join(", ")}');

      context.appendThought(thought.toString());

      GameLogger.instance.d(
        '[事实分析] 完成 - 核心矛盾: ${response['core_conflict']}, '
        '关键事实: ${keyFacts.length}个, 关注玩家: ${focusPlayers.length}个',
      );
    } catch (e) {
      GameLogger.instance.e('[事实分析] 失败: $e');
      // 降级：使用空数据
      context.setStepOutput('core_conflict', '当前处于信息收集阶段，需要观察各方表现');
      context.setStepOutput('key_facts', <KeyFact>[]);
      context.setStepOutput('focus_players', <String>[]);
      context.setStepOutput('working_memory', workingMemory);
    }

    return context;
  }

  /// 构建System Prompt
  String _buildSystemPrompt() {
    return '''
你是狼人杀游戏分析专家。从大量游戏信息中提取最关键的事实和矛盾点。

要点：
1. 识别当前最核心的矛盾（如预言家对跳、被多人怀疑的玩家等）
2. 提取5个左右最重要的事实（不是所有事实，只要关键的）
3. 识别3个左右需要重点关注的玩家
4. 保持客观，基于已知信息分析

输出：核心矛盾描述 + 关键事实列表 + 重点关注玩家列表
''';
  }

  /// 构建User Prompt
  String _buildUserPrompt(ReasoningContext context, WorkingMemory? memory) {
    final player = context.player;
    final state = context.state;
    final skill = context.skill;

    // 获取所有对玩家可见的事件
    final visibleEvents = state.events
        .where((event) => event.isVisibleTo(player))
        .toList();

    // 构建事件描述
    final eventNarratives = StringBuffer();
    if (visibleEvents.isEmpty) {
      eventNarratives.writeln('暂无事件');
    } else {
      for (var i = 0; i < visibleEvents.length; i++) {
        final event = visibleEvents[i];
        eventNarratives.writeln('${i + 1}. ${event.toNarrative()}');
      }
    }

    return '''
**我的信息**
我是${player.name}，角色：${player.role.name}
${memory?.secretKnowledge.toText() ?? ''}

**当前局势** (第${state.day}天，${skill.name})
存活玩家数: ${state.alivePlayers.length}
存活玩家: ${state.alivePlayers.map((p) => p.name).join(', ')}

**游戏事件历史**
$eventNarratives

---

**任务**: 分析以上信息，提取关键内容。

输出JSON：
```json
{
  "core_conflict": "当前最核心的矛盾或问题（1句话）",
  "key_facts": [
    {"description": "关键事实1", "importance": 10},
    {"description": "关键事实2", "importance": 8}
  ],
  "focus_players": ["需要重点关注的玩家1", "玩家2"]
}
```

**Few-Shot示例**:

场景1 - 预言家对跳:
```json
{
  "core_conflict": "3号和7号都声称是预言家，需要判断谁是真预言家",
  "key_facts": [
    {"description": "3号第1天跳预言家，给5号发金水", "importance": 10},
    {"description": "7号第2天跳预言家，给3号发查杀", "importance": 10},
    {"description": "5号被3号验金水后发言支持3号", "importance": 7}
  ],
  "focus_players": ["3号玩家", "7号玩家", "5号玩家"]
}
```

场景2 - 信息收集阶段:
```json
{
  "core_conflict": "当前处于信息收集阶段，需要观察各方表现",
  "key_facts": [
    {"description": "第1天晚上1号玩家被刀", "importance": 8},
    {"description": "2号玩家发言较为激进，怀疑4号", "importance": 5}
  ],
  "focus_players": ["2号玩家", "4号玩家"]
}
```

场景3 - 投票分歧:
```json
{
  "core_conflict": "场上出现投票分歧，6号和9号得票数相近",
  "key_facts": [
    {"description": "6号被3号、5号、7号怀疑", "importance": 9},
    {"description": "9号发言逻辑混乱，被2号、8号质疑", "importance": 8},
    {"description": "4号作为村民带节奏投6号", "importance": 6}
  ],
  "focus_players": ["6号玩家", "9号玩家", "4号玩家"]
}
```
''';
  }

  /// 创建初始的工作记忆
  WorkingMemory _createInitialMemory(
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

    return WorkingMemory(secretKnowledge: secretKnowledge);
  }
}
