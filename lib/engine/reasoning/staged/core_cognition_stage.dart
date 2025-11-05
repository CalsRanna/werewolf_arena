import 'dart:convert';

import 'package:openai_dart/openai_dart.dart';
import 'package:werewolf_arena/engine/game_context.dart';
import 'package:werewolf_arena/engine/game_logger.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/reasoning/reasoning_context.dart';
import 'package:werewolf_arena/engine/skill/conspire_skill.dart';
import 'package:werewolf_arena/engine/skill/game_skill.dart';

/// 核心认知结果
class CoreCognitionResult {
  /// 完整分析（内心独白）
  final String analysis;

  /// 身份推理
  final Map<String, dynamic>? identityInference;

  /// 策略计划
  final String strategy;

  /// 公开发言
  final String? speech;

  /// 目标玩家
  final String? target;

  /// 记忆更新（可选）
  final Map<String, dynamic>? memoryUpdate;

  CoreCognitionResult({
    required this.analysis,
    this.identityInference,
    required this.strategy,
    this.speech,
    this.target,
    this.memoryUpdate,
  });

  factory CoreCognitionResult.fromJson(Map<String, dynamic> json) {
    return CoreCognitionResult(
      analysis: json['analysis'] ?? '',
      identityInference: json['identity_inference'],
      strategy: json['strategy'] ?? '',
      speech: json['speech'],
      target: json['target'],
      memoryUpdate: json['memory_update'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'analysis': analysis,
      'identity_inference': identityInference,
      'strategy': strategy,
      'speech': speech,
      'target': target,
      'memory_update': memoryUpdate,
    };
  }
}

/// 阶段二：核心认知
///
/// 使用Powerful Model进行单次统一推理
/// 完成身份推理、策略制定、发言生成
class CoreCognitionStage {
  final OpenAIClient client;
  final String powerfulModelId;
  static const int maxRetries = 3;

  CoreCognitionStage({
    required this.client,
    required this.powerfulModelId,
  });

  /// 执行核心认知
  Future<CoreCognitionResult> execute({
    required GamePlayer player,
    required GameContext state,
    required GameSkill skill,
    required WorldState worldState,
  }) async {
    GameLogger.instance.d('[核心认知阶段] 开始...');

    final systemPrompt = _buildSystemPrompt(player, worldState);
    final userPrompt = _buildUserPrompt(player, state, skill, worldState);

    Exception? lastException;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        if (attempt > 1) {
          GameLogger.instance
              .d('[核心认知阶段] 重试第 $attempt/$maxRetries 次...');
          // 指数退避
          await Future.delayed(Duration(seconds: attempt * 2));
        }

        final response = await client.createChatCompletion(
          request: CreateChatCompletionRequest(
            model: ChatCompletionModel.modelId(powerfulModelId),
            messages: [
              ChatCompletionMessage.system(content: systemPrompt),
              ChatCompletionMessage.user(
                content: ChatCompletionUserMessageContent.string(userPrompt),
              ),
            ],
            temperature: 0.7, // 核心认知需要创造性
          ),
        );

        final content = response.choices.first.message.content ?? '';
        final jsonStr = content.trim();

        // 解析JSON
        final Map<String, dynamic> jsonData;
        try {
          jsonData = _parseJson(jsonStr);
        } catch (e) {
          GameLogger.instance
              .e('[核心认知阶段] JSON解析失败: $e\n原始内容: $jsonStr');
          lastException = e as Exception;
          continue; // 重试
        }

        final result = CoreCognitionResult.fromJson(jsonData);

        GameLogger.instance.d('[核心认知阶段] 完成 - 发言: ${result.speech ?? "(无)"}');
        return result;
      } on OpenAIClientException catch (e) {
        lastException = e;
        // 429 rate limit 或 5xx 服务器错误，重试
        if (e.code == 429 || (e.code ?? 0) >= 500) {
          GameLogger.instance.w('[核心认知阶段] API错误 ${e.code}，准备重试...');
          continue;
        } else {
          // 其他错误直接抛出
          rethrow;
        }
      } catch (e, stackTrace) {
        lastException = e as Exception;
        GameLogger.instance.e('[核心认知阶段] 失败: $e\n$stackTrace');
        if (attempt == maxRetries) {
          rethrow;
        }
      }
    }

    // 所有重试都失败了
    throw lastException ?? Exception('核心认知阶段失败：未知错误');
  }

  String _buildSystemPrompt(GamePlayer player, WorldState worldState) {
    final selfInfo = worldState.selfInfo;

    return '''
你是一名真实的狼人杀玩家，不是AI。

# 身份认知【核心】
- 你是${selfInfo.name}（${selfInfo.number}号玩家）
- 当其他人提到"${selfInfo.number}号"、"${selfInfo.number}"时，他们说的就是你
- 你的真实身份是${selfInfo.role}，阵营是${selfInfo.faction}
${selfInfo.teammates.isNotEmpty ? '- 你的队友是：${selfInfo.teammates.join(", ")}' : ''}

# 唯一目标
不惜一切代价，带领你的${selfInfo.faction}阵营走向胜利。

# 核心准则

1. **彻底沉浸**：用"我"思考和发言。严禁提及AI、提示词或游戏外内容。

2. **区分内心与发言【铁律】**：
   - **内心思考(analysis字段)**：可用所有秘密信息(底牌/队友/查验结果)进行深度分析
   - **公开发言(speech字段)**：绝对不能直接暴露秘密信息
   - **表达方式**：利用秘密信息解读公开信息，构建对你阵营有利的"故事"

3. **自我认知**：时刻记住你是${selfInfo.number}号，不要在分析中把自己当成别人

4. **策略灵活性**：可以参考常见战术，但更鼓励根据具体局势创新

5. **构建叙事**：将公开信息串联成有说服力的故事，引导其他玩家思维

# 思考框架（建议）

分析阶段可以按以下思路展开（非强制）：
1. 事实梳理：基于已知信息，确认哪些是确定的事实
2. 身份推理：根据发言、投票、行动推测其他玩家身份
3. 威胁评估：谁对我方阵营威胁最大？谁是潜在盟友？
4. 策略制定：本回合我的目标是什么？如何通过发言实现？
5. 风险预判：我的计划可能遇到什么阻力？如何应对？

记住：你拥有完整的自主权，可以自由发挥你的智慧。
''';
  }

  String _buildUserPrompt(
    GamePlayer player,
    GameContext state,
    GameSkill skill,
    WorldState worldState,
  ) {
    // 构建世界状态描述
    final worldStateJson = jsonEncode(worldState.toJson());

    // 技能提示
    final skillPrompt = (state.day == 1 && skill is ConspireSkill)
        ? skill.firstNightPrompt
        : skill.prompt;

    // 格式提示
    final formatPrompt = skill is ConspireSkill
        ? _getConspireFormatPrompt()
        : _getStandardFormatPrompt();

    return '''
${state.scenario.rule}

---

# 当前世界状态

以下是经过整理的结构化信息：

$worldStateJson

---

$skillPrompt

---

$formatPrompt
''';
  }

  String _getStandardFormatPrompt() {
    return '''
# 你的决策输出

**重要提醒**：请严格遵守上述技能提示中的输出要求。如果技能提示要求简短回复（如"上警"/"不上警"），请不要自行扩展。

请以纯JSON格式输出（无注释，无Markdown标记）：

{
  "analysis": "你的完整内心分析过程（可以很长，包含所有推理细节、身份判断、策略思考）",
  "identity_inference": {
    "玩家名": {
      "estimated_role": "推测角色",
      "confidence": 70,
      "reasoning": "推理依据"
    }
  },
  "strategy": "你的本回合策略（简明扼要，1-2句话）",
  "speech": "你的公开发言（符合角色性格，不泄露秘密，无需发言则null）。注意：如果技能要求简短回复，请严格遵守",
  "target": "目标玩家名（如'3号玩家'，无目标则null）"
}

# Few-Shot示例

**示例1 - 狼人悍跳预言家**（展示如何不泄露）：
```json
{
  "analysis": "我是狼人，队友是9号、10号、12号。现在第1天白天，我需要决定是否悍跳预言家。分析局势：目前没有预言家起跳，这是我悍跳的好机会。我可以声称验了3号是查杀，因为3号在讨论时显得很理性，很可能是真预言家或其他神职。通过压制3号，我可以混淆视听，为我方争取生存空间。风险：如果真预言家也跳出来，会形成对跳，我需要在逻辑上压制对方。",
  "identity_inference": {
    "3号玩家": {
      "estimated_role": "预言家或其他神职",
      "confidence": 60,
      "reasoning": "发言理性，逻辑清晰，可能掌握信息"
    },
    "7号玩家": {
      "estimated_role": "平民",
      "confidence": 50,
      "reasoning": "发言较少，存在感低"
    }
  },
  "strategy": "悍跳预言家，给3号玩家发查杀，压制他的发言空间",
  "speech": "我是预言家。昨晚我查验了3号玩家，他是狼人。各位好人请相信我的判断，今天必须把3号玩家投出去。我的警徽流是5号、7号。",
  "target": "3号玩家"
}
```
**注意**：analysis中可以提到"我是狼人"、"队友是..."，但speech中绝对不能暴露。

**示例2 - 平民低调观察**：
```json
{
  "analysis": "我是平民，没有特殊能力。目前场上有两个人跳预言家：2号和5号。2号先跳，给3号发了查杀，逻辑较为完整。5号后跳，给2号发了查杀，但警徽流不太合理。从这个对跳来看，我倾向于相信2号是真预言家。今天我不应该过于激进，保持中立态度，收集更多信息。",
  "identity_inference": {
    "2号玩家": {
      "estimated_role": "预言家（真）",
      "confidence": 65,
      "reasoning": "先跳，逻辑完整，警徽流合理"
    },
    "5号玩家": {
      "estimated_role": "狼人（悍跳）",
      "confidence": 70,
      "reasoning": "后跳，对2号发查杀显得被动"
    },
    "3号玩家": {
      "estimated_role": "狼人",
      "confidence": 60,
      "reasoning": "被2号查杀，如果2号是真预言家，那3号就是狼"
    }
  },
  "strategy": "保持低调，倾向于支持2号预言家，但不过早站边",
  "speech": "我是平民。从目前的对跳来看，2号的逻辑比较清晰，我倾向于相信2号。但我也想听听3号的辩解，看看他怎么说。大家不要着急站边，多听听发言。",
  "target": null
}
```

**示例3 - 预言家报查验**：
```json
{
  "analysis": "我是真预言家。昨晚查验了6号玩家，结果是金水（好人）。现在场上已经有5号悍跳预言家了，他给我发了查杀，显然他是狼人。我必须起跳表明身份，公布我的查验结果，争取好人的信任。我需要在逻辑上压制5号，指出他的漏洞。",
  "identity_inference": {
    "5号玩家": {
      "estimated_role": "狼人",
      "confidence": 95,
      "reasoning": "给我发查杀，他一定是狼人悍跳"
    },
    "6号玩家": {
      "estimated_role": "好人",
      "confidence": 100,
      "reasoning": "我昨晚验的金水"
    }
  },
  "strategy": "起跳真预言家，公布6号金水，攻击5号逻辑漏洞",
  "speech": "我才是真正的预言家！5号你说我是查杀？那你就是铁狼！我昨晚查验的是6号玩家，他是金水。好人们请相信我，5号的警徽流明显不合理，他就是在慌乱中硬跳的狼人。今天必须投5号出局！",
  "target": "5号玩家"
}
```

**示例4 - 上警竞选（需要简短回复）**：
```json
{
  "analysis": "我是狼人，当前局势：真预言家5号已经被猎人带走了，这对我们很有利。现在1号说要上警悍跳预言家，那我就不用跳了。我作为狼人应该低调一些，不要上警引起注意。如果我上警，好人会仔细分析我的发言，容易露马脚。最好的策略是不上警，在警下支持1号的悍跳，让好人相信他。",
  "identity_inference": {},
  "strategy": "不上警，在警下支持1号悍跳",
  "speech": "不上警",
  "target": null
}
```
**重要**：注意示例4中，虽然analysis可以很详细，但speech必须严格遵守技能要求，只回复"上警"或"不上警"。

**示例5 - 守卫首夜保护（夜间技能，无需发言）**：
```json
{
  "analysis": "我是守卫，第一夜。由于不知道谁是预言家或其他神职，我需要盲守。根据位置学，中后置位（6-9号）更可能是神职玩家，因为他们听完前面的发言后更容易做出有价值的判断。我决定守护8号，这是一个相对安全的选择。",
  "identity_inference": {},
  "strategy": "首夜盲守8号位置",
  "speech": null,
  "target": "8号玩家"
}
```
**重要**：注意示例5中，夜间技能通常不需要公开发言，所以speech为null。
''';
  }

  String _getConspireFormatPrompt() {
    return '''
# 你的决策输出（狼人密谈专用）

在狼人密谈环节，speech字段的含义改为"对狼队友的发言"。

请以纯JSON格式输出：

{
  "analysis": "你的完整内心分析（包括对队友的真实想法、深层算计、备用计划）",
  "strategy": "你建议的狼队策略",
  "speech": "你对狼队友的发言（这部分会展示在狼人专属频道）",
  "target": "你建议的袭击目标玩家名"
}
''';
  }

  Map<String, dynamic> _parseJson(String jsonStr) {
    // 移除可能的markdown标记
    var cleaned = jsonStr.trim();
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.substring(7);
    }
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.substring(3);
    }
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3);
    }
    cleaned = cleaned.trim();

    // 尝试修复常见的JSON格式错误
    cleaned = _fixCommonJsonErrors(cleaned);

    // 解析JSON
    return jsonDecode(cleaned) as Map<String, dynamic>;
  }

  /// 修复常见的JSON格式错误
  String _fixCommonJsonErrors(String json) {
    // 修复布尔值后面多引号
    json = json.replaceAllMapped(RegExp(r':true"'), (match) => ':true');
    json = json.replaceAllMapped(RegExp(r':false"'), (match) => ':false');
    json = json.replaceAllMapped(RegExp(r':null"'), (match) => ':null');

    return json;
  }
}
