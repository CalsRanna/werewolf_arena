import 'package:openai_dart/openai_dart.dart';
import 'package:werewolf_arena/engine/game_logger.dart';
import 'package:werewolf_arena/engine/reasoning/memory/social_analyzer.dart';
import 'package:werewolf_arena/engine/reasoning/memory/social_network.dart';
import 'package:werewolf_arena/engine/reasoning/memory/working_memory.dart';
import 'package:werewolf_arena/engine/reasoning/reasoning_context.dart';
import 'package:werewolf_arena/engine/reasoning/step/reasoning_step.dart';

/// 身份推理步骤
///
/// CoT推理链的第二步：基于关键事实和秘密信息，推理所有玩家的身份
/// 输出：每个玩家的身份推测（角色+置信度+依据）
class IdentityInferenceStep extends ReasoningStep {
  final String modelId;

  IdentityInferenceStep({required this.modelId});

  @override
  String get name => 'identity_inference';

  @override
  String get description => '推理所有玩家的身份概率';

  @override
  Future<ReasoningContext> execute(
    ReasoningContext context,
    OpenAIClient client,
  ) async {
    GameLogger.instance.d('[身份推理] 开始推理...');

    // 1. 获取前一步的分析结果
    final coreConflict = context.getStepOutput<String>('core_conflict') ?? '无';
    final keyFacts = context.getStepOutput<List<KeyFact>>('key_facts') ?? [];
    final focusPlayers =
        context.getStepOutput<List<String>>('focus_players') ?? [];
    final workingMemory = context.getStepOutput<WorkingMemory>(
      'working_memory',
    );

    // 2. 构建Prompt
    final systemPrompt = _buildSystemPrompt();
    final userPrompt = _buildUserPrompt(
      context,
      coreConflict,
      keyFacts,
      focusPlayers,
      workingMemory,
    );

    // 3. 调用LLM（带重试）
    try {
      final response = await request(
        client: client,
        modelId: modelId,
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        context: context,
      );

      // 4. 解析响应并更新WorkingMemory
      final identityEstimates = <String, IdentityEstimate>{};
      response.forEach((playerName, data) {
        if (data is Map<String, dynamic>) {
          identityEstimates[playerName] = IdentityEstimate(
            estimatedRole: data['role'] as String? ?? '未知',
            confidence: (data['confidence'] as num?)?.toInt() ?? 50,
            reasoning: data['reasoning'] as String? ?? '暂无依据',
          );
        }
      });

      // 更新WorkingMemory中的身份推测
      if (workingMemory != null) {
        identityEstimates.forEach((playerName, estimate) {
          workingMemory.identityEstimates[playerName] = estimate;
        });

        // 5. 更新社交网络（基于身份推理结果）
        final player = context.player;
        final state = context.state;

        // 初始化或获取现有社交网络
        var socialNetwork = workingMemory.socialNetwork;
        socialNetwork ??= SocialNetwork.initial(
          ownerId: player.id,
          allPlayers: state.players,
        );

        // 基于身份推理更新社交网络
        socialNetwork = SocialAnalyzer.updateFromIdentityInference(
          currentNetwork: socialNetwork,
          identityEstimates: identityEstimates,
          player: player,
          state: state,
        );

        // 保存更新后的社交网络
        workingMemory.updateSocialNetwork(socialNetwork);

        context.setStepOutput('working_memory', workingMemory);
        context.setStepOutput('social_network', socialNetwork);
      }

      // 6. 记录到思考链
      final thought = StringBuffer();
      thought.writeln('[步骤2: 身份推理]');
      thought.writeln();
      identityEstimates.forEach((playerName, estimate) {
        thought.writeln(
          '$playerName: ${estimate.estimatedRole} (置信度: ${estimate.confidence}%)',
        );
        thought.writeln('  依据: ${estimate.reasoning}');
      });

      context.appendThought(thought.toString());

      GameLogger.instance.d('[身份推理] 完成 - 推理了 ${identityEstimates.length} 个玩家');
    } catch (e) {
      GameLogger.instance.e('[身份推理] 失败: $e');
    }

    return context;
  }

  /// 构建System Prompt
  String _buildSystemPrompt() {
    return '''
你是狼人杀身份推理专家。基于公开信息和你的秘密知识，推理其他玩家身份。

推理原则：
1. 每个结论需有依据
2. 用置信度(0-100%)表达不确定性
3. 区分秘密信息(角色/队友/查验)与公开信息(发言/投票/死亡)

输出每个玩家的：最可能身份 + 置信度 + 依据(1-2句)
''';
  }

  /// 构建User Prompt
  String _buildUserPrompt(
    ReasoningContext context,
    String coreConflict,
    List<KeyFact> keyFacts,
    List<String> focusPlayers,
    WorkingMemory? memory,
  ) {
    final player = context.player;
    final state = context.state;

    // 获取存活的其他玩家
    final otherPlayers = state.alivePlayers
        .where((p) => p.id != player.id)
        .map((p) => p.name)
        .toList();

    return '''
**我的信息**
我是${player.name}，角色：${player.role.name}
${memory?.secretKnowledge.toText() ?? ''}

**局势** (第${state.day}天)
核心矛盾：$coreConflict

**关键事实**
${keyFacts.isEmpty ? '暂无' : keyFacts.asMap().entries.map((e) => '${e.key + 1}. ${e.value.description}').join('\n')}

**待推理玩家**: ${otherPlayers.join(', ')}

---

输出JSON格式：
```json
{
  "玩家名称": {
    "role": "角色(狼人/预言家/村民/女巫/守卫/猎人)",
    "confidence": 0-100整数,
    "reasoning": "依据(1-2句)"
  }
}
```

**Few-Shot示例**:

场景1 - 预言家对跳:
```json
{
  "2号玩家": {
    "role": "狼人",
    "confidence": 85,
    "reasoning": "给真预言家发查杀，逻辑站不住脚，疑似悍跳狼"
  },
  "3号玩家": {
    "role": "预言家",
    "confidence": 75,
    "reasoning": "查验信息准确，发言逻辑清晰，可能是真预言家"
  },
  "5号玩家": {
    "role": "村民",
    "confidence": 60,
    "reasoning": "发言中立，没有明显神牌特征，可能是平民"
  }
}
```

场景2 - 分析可疑行为:
```json
{
  "4号玩家": {
    "role": "狼人",
    "confidence": 70,
    "reasoning": "投票行为可疑，多次为狼队辩护"
  },
  "6号玩家": {
    "role": "女巫",
    "confidence": 65,
    "reasoning": "暗示知道夜间死亡信息，可能是女巫"
  }
}
```
''';
  }
}
