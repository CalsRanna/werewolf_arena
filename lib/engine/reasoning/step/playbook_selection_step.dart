import 'package:openai_dart/openai_dart.dart';
import 'package:werewolf_arena/engine/game_logger.dart';
import 'package:werewolf_arena/engine/reasoning/playbook/playbook.dart';
import 'package:werewolf_arena/engine/reasoning/playbook/playbook_library.dart';
import 'package:werewolf_arena/engine/reasoning/reasoning_context.dart';
import 'package:werewolf_arena/engine/reasoning/step/reasoning_step.dart';

/// 剧本选择步骤（LLM版本）
///
/// 从剧本库中选择最适合当前场景的战术剧本
/// 使用LLM分析当前局势，从推荐剧本中选择最优方案
class PlaybookSelectionStep extends ReasoningStep {
  final String modelId;

  PlaybookSelectionStep({required this.modelId});

  @override
  String get name => 'playbook_selection';

  @override
  String get description => '选择合适的战术剧本';

  @override
  Future<ReasoningContext> execute(
    ReasoningContext context,
    OpenAIClient client,
  ) async {
    GameLogger.instance.d('[剧本选择] 开始选择...');

    final player = context.player;
    final state = context.state;

    // 1. 从剧本库获取推荐列表
    final recommendedPlaybooks = PlaybookLibrary.recommend(
      state: state,
      player: player,
    );

    // 2. 如果没有推荐剧本，跳过LLM调用
    if (recommendedPlaybooks.isEmpty) {
      context.setStepOutput('selected_playbook', null);
      context.appendThought('[步骤4: 剧本选择] 暂无合适的剧本');
      GameLogger.instance.d('[剧本选择] 完成 - 无推荐剧本');
      return context;
    }

    // 3. 构建Prompt并调用LLM
    try {
      final strategy = context.getStepOutput<Map<String, dynamic>>('strategy');
      final systemPrompt = _buildSystemPrompt();
      final userPrompt = _buildUserPrompt(
        context,
        recommendedPlaybooks,
        strategy,
      );

      final response = await request(
        client: client,
        modelId: modelId,
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        context: context,
      );

      // 4. 解析响应
      final selectedPlaybookId = response['selected_playbook_id'] as String?;

      // 5. 查找选中的剧本
      Playbook? foundPlaybook;
      if (selectedPlaybookId != null) {
        try {
          foundPlaybook = recommendedPlaybooks.firstWhere(
            (p) => p.id == selectedPlaybookId,
          );
        } catch (e) {
          // 如果找不到指定的剧本，使用第一个
          foundPlaybook = recommendedPlaybooks.isNotEmpty
              ? recommendedPlaybooks.first
              : null;
        }
      }
      final selectedPlaybook = foundPlaybook;

      // 6. 存入上下文
      context.setStepOutput('selected_playbook', selectedPlaybook);

      // 7. 记录到思考链
      if (selectedPlaybook != null) {
        context.appendThought('''
[步骤4: 剧本选择]
选择的剧本: ${selectedPlaybook.name}
核心目标: ${selectedPlaybook.coreGoal}
''');
        GameLogger.instance.d('[剧本选择] 完成 - 选择了: ${selectedPlaybook.name}');
      } else {
        context.appendThought('[步骤4: 剧本选择] 不使用剧本');
        GameLogger.instance.d('[剧本选择] 完成 - 不使用剧本');
      }
    } catch (e) {
      GameLogger.instance.e('[剧本选择] 失败: $e');
      // 降级：使用第一个推荐
      final fallbackPlaybook = recommendedPlaybooks.first;
      context.setStepOutput('selected_playbook', fallbackPlaybook);
      context.appendThought('''
[步骤4: 剧本选择]
选择的剧本: ${fallbackPlaybook.name}（降级选择）
核心目标: ${fallbackPlaybook.coreGoal}
''');
    }

    return context;
  }

  /// 构建System Prompt
  String _buildSystemPrompt() {
    return '''
你是狼人杀战术专家。基于当前局势和策略，从候选剧本中选择最合适的战术打法。

要点：
1. 分析当前局势特点（天数、存活人数、已暴露信息）
2. 评估各个剧本的适用性和成功率
3. 选择最符合策略目标的剧本

输出：选中的剧本ID或null（不使用剧本）
''';
  }

  /// 构建User Prompt
  String _buildUserPrompt(
    ReasoningContext context,
    List<Playbook> recommendedPlaybooks,
    Map<String, dynamic>? strategy,
  ) {
    final player = context.player;
    final state = context.state;
    final skill = context.skill;

    // 构建剧本列表
    final playbookDescriptions = StringBuffer();
    for (var i = 0; i < recommendedPlaybooks.length; i++) {
      final playbook = recommendedPlaybooks[i];
      playbookDescriptions.writeln('''
**剧本${i + 1}: ${playbook.name}** (ID: ${playbook.id})
描述: ${playbook.description}
核心目标: ${playbook.coreGoal}
风险: ${playbook.risks.join(', ')}
成功标准: ${playbook.successCriteria}
---
''');
    }

    return '''
**我的信息**
我是${player.name}，角色：${player.role.name}
当前行动：${skill.name}

**局势** (第${state.day}天)
存活人数: ${state.alivePlayers.length}

**我的策略目标**
${strategy?['goal'] ?? '保持观察'}

**候选剧本**
$playbookDescriptions

---

**任务**: 分析候选剧本，选择最适合当前局势和我的策略目标的一个。

输出JSON：
```json
{
  "selected_playbook_id": "剧本ID或null",
  "reason": "选择理由(1-2句)"
}
```

**Few-Shot示例**:

场景1 - 狼人首日起跳:
```json
{
  "selected_playbook_id": "werewolf_jump_seer",
  "reason": "第1天信息少，悍跳预言家可抢占话语权，混淆好人视听"
}
```

场景2 - 预言家有查验结果:
```json
{
  "selected_playbook_id": "seer_reveal",
  "reason": "已验出狼人，应该起跳公布身份和查验结果"
}
```

场景3 - 局势不明朗:
```json
{
  "selected_playbook_id": null,
  "reason": "当前信息不足，使用剧本可能暴露意图，保持灵活更优"
}
```
''';
  }
}
