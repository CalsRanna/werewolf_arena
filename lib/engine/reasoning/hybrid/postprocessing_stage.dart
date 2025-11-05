import 'dart:convert';

import 'package:openai_dart/openai_dart.dart';
import 'package:werewolf_arena/engine/game_logger.dart';
import 'package:werewolf_arena/engine/reasoning/hybrid/core_cognition_stage.dart';
import 'package:werewolf_arena/engine/skill/conspire_skill.dart';
import 'package:werewolf_arena/engine/skill/game_skill.dart';

/// 后处理结果
class PostprocessingResult {
  /// 是否通过安全检查
  final bool passed;

  /// 最终发言（可能被修改）
  final String? finalSpeech;

  /// 检查报告
  final String report;

  /// 是否需要重新生成
  final bool needsRegeneration;

  PostprocessingResult({
    required this.passed,
    this.finalSpeech,
    required this.report,
    this.needsRegeneration = false,
  });

  factory PostprocessingResult.fromJson(Map<String, dynamic> json) {
    return PostprocessingResult(
      passed: json['passed'] ?? true,
      finalSpeech: json['final_speech'],
      report: json['report'] ?? '',
      needsRegeneration: json['needs_regeneration'] ?? false,
    );
  }
}

/// 阶段三：行动后处理
///
/// 使用Fast Model进行安全检查
/// 确保发言不泄露秘密信息、符合角色设定
class PostprocessingStage {
  final OpenAIClient client;
  final String fastModelId;
  static const int maxRetries = 3;

  PostprocessingStage({
    required this.client,
    required this.fastModelId,
  });

  /// 执行后处理
  Future<PostprocessingResult> execute({
    required String playerName,
    required String role,
    required String faction,
    required List<String> teammates,
    required CoreCognitionResult cognitionResult,
    required GameSkill skill,
  }) async {
    GameLogger.instance.d('[后处理阶段] 开始安全检查...');

    // 如果没有发言，直接通过
    if (cognitionResult.speech == null || cognitionResult.speech!.isEmpty) {
      return PostprocessingResult(
        passed: true,
        finalSpeech: cognitionResult.speech,
        report: '无发言内容，跳过检查',
      );
    }

    // 如果是狼人密谈，跳过安全检查（队友间可以自由讨论）
    if (skill is ConspireSkill) {
      GameLogger.instance.d('[后处理阶段] 狼人密谈，跳过安全检查');
      return PostprocessingResult(
        passed: true,
        finalSpeech: cognitionResult.speech,
        report: '狼人密谈，允许讨论队友',
      );
    }

    final systemPrompt = _buildSystemPrompt();
    final userPrompt = _buildUserPrompt(
      playerName: playerName,
      role: role,
      faction: faction,
      teammates: teammates,
      speech: cognitionResult.speech!,
      strategy: cognitionResult.strategy,
    );

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        if (attempt > 1) {
          GameLogger.instance
              .d('[后处理阶段] 重试第 $attempt/$maxRetries 次...');
          // 指数退避
          await Future.delayed(Duration(seconds: attempt * 2));
        }

        final response = await client.createChatCompletion(
          request: CreateChatCompletionRequest(
            model: ChatCompletionModel.modelId(fastModelId),
            messages: [
              ChatCompletionMessage.system(content: systemPrompt),
              ChatCompletionMessage.user(
                content: ChatCompletionUserMessageContent.string(userPrompt),
              ),
            ],
            temperature: 0.2, // 安全检查需要稳定性
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
              .e('[后处理阶段] JSON解析失败: $e\n原始内容: $jsonStr');
          // JSON解析失败时，直接使用原始发言
          if (attempt == maxRetries) {
            return PostprocessingResult(
              passed: true,
              finalSpeech: cognitionResult.speech,
              report: 'JSON解析失败，使用原始发言',
            );
          }
          continue; // 重试
        }

        final result = PostprocessingResult.fromJson(jsonData);

        if (result.passed) {
          GameLogger.instance.d('[后处理阶段] 安全检查通过');
        } else {
          GameLogger.instance.w('[后处理阶段] 安全检查未通过: ${result.report}');
        }

        return result;
      } on OpenAIClientException catch (e) {
        // 429 rate limit 或 5xx 服务器错误，重试
        if (e.code == 429 || (e.code ?? 0) >= 500) {
          GameLogger.instance.w('[后处理阶段] API错误 ${e.code}，准备重试...');
          continue;
        } else {
          // 其他错误直接抛出
          rethrow;
        }
      } catch (e, stackTrace) {
        GameLogger.instance.e('[后处理阶段] 失败: $e\n$stackTrace');
        if (attempt == maxRetries) {
          // 失败时使用原始发言
          return PostprocessingResult(
            passed: true,
            finalSpeech: cognitionResult.speech,
            report: '安全检查失败，使用原始发言',
          );
        }
      }
    }

    // 所有重试都失败了，使用原始发言
    return PostprocessingResult(
      passed: true,
      finalSpeech: cognitionResult.speech,
      report: '安全检查失败（重试耗尽），使用原始发言',
    );
  }

  String _buildSystemPrompt() {
    return '''
你是狼人杀游戏的安全检查助手。

# 任务
检查玩家的公开发言是否存在以下问题：
1. 泄露秘密信息（如狼人身份、队友名单、私密查验结果等）
2. 违反角色设定（如平民声称自己有特殊能力）
3. 包含不当言论（攻击、歧视等）

# 检查原则
- **宽松为主**：只标记明显的问题，不要过度严格
- **允许策略性伪装**：玩家可以假装其他角色（如狼人悍跳预言家），这是正常策略
- **区分暗示和泄露**：巧妙的暗示是允许的，但直接泄露队友是不允许的

# 输出格式
纯JSON（无注释）：
{
  "passed": true/false,
  "report": "检查报告",
  "final_speech": "修正后的发言（如果需要修改）或null",
  "needs_regeneration": false
}
''';
  }

  String _buildUserPrompt({
    required String playerName,
    required String role,
    required String faction,
    required List<String> teammates,
    required String speech,
    required String strategy,
  }) {
    return '''
# 待检查的发言

**玩家信息**
- 名称: $playerName
- 角色: $role
- 阵营: $faction
${teammates.isNotEmpty ? '- 队友: ${teammates.join(", ")}' : ''}

**策略**
$strategy

**公开发言**
"$speech"

---

# 检查要点

1. **秘密泄露检查**
   - 是否直接提到自己是狼人？
   - 是否直接点名队友？（如"我和5号、9号是狼队"）
   - 是否泄露只有特定角色才知道的信息？

2. **角色一致性检查**
   - 如果是平民，是否声称自己有特殊能力？
   - 如果是狼人悍跳预言家，这是正常策略（允许）

3. **语言安全检查**
   - 是否包含攻击性、歧视性言论？

# 输出JSON

如果发言无问题：
```json
{
  "passed": true,
  "report": "发言符合规范",
  "final_speech": null,
  "needs_regeneration": false
}
```

如果发言有轻微问题（可修正）：
```json
{
  "passed": true,
  "report": "发言存在轻微问题，已自动修正：XXX",
  "final_speech": "修正后的发言",
  "needs_regeneration": false
}
```

如果发言有严重问题（需要重新生成）：
```json
{
  "passed": false,
  "report": "发言存在严重问题：直接泄露了队友身份",
  "final_speech": null,
  "needs_regeneration": true
}
```

# 示例

**示例1 - 正常悍跳（通过）**
输入："我是预言家，昨晚验了3号，他是狼人"
玩家实际是狼人，这是正常的悍跳策略。
输出：
```json
{
  "passed": true,
  "report": "狼人悍跳预言家，这是正常策略",
  "final_speech": null,
  "needs_regeneration": false
}
```

**示例2 - 直接泄露队友（不通过）**
输入："兄弟们，我和5号、9号一起投3号吧"
这直接暴露了队友关系。
输出：
```json
{
  "passed": false,
  "report": "直接泄露了队友身份（5号、9号）",
  "final_speech": null,
  "needs_regeneration": true
}
```

**示例3 - 巧妙暗示（通过）**
输入："我建议大家关注一下5号和9号的发言，他们的逻辑很有道理"
这只是表达支持，没有泄露队友关系。
输出：
```json
{
  "passed": true,
  "report": "发言中表达了对其他玩家的支持，但没有泄露秘密",
  "final_speech": null,
  "needs_regeneration": false
}
```
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
