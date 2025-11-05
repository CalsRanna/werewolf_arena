import 'package:werewolf_arena/engine/game_context.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';

/// 战术剧本抽象基类
///
/// 将抽象的"高级战术"具体化为可执行的"剧本"
/// 包含触发条件、执行步骤、关键话术
abstract class Playbook {
  /// 剧本ID（唯一标识）
  String get id;

  /// 剧本名称
  String get name;

  /// 剧本描述
  String get description;

  /// 适用角色列表
  List<String> get applicableRoles;

  /// 判断此剧本是否可以激活
  ///
  /// [state] 游戏状态
  /// [player] 当前玩家
  /// 返回 true 表示满足触发条件
  bool canActivate(GameContext state, GamePlayer player);

  /// 核心目标
  String get coreGoal;

  /// 执行步骤
  List<PlaybookStep> get steps;

  /// 关键话术库
  List<String> get keyPhrases;

  /// 风险提示
  List<String> get risks;

  /// 成功标志
  String get successCriteria;

  /// 生成完整的剧本指导Prompt
  ///
  /// 用于在策略规划时指导LLM使用此剧本
  String toPrompt() {
    final stepsText = steps.asMap().entries.map((e) {
      final step = e.value;
      return '${e.key + 1}. [${step.phase}] ${step.action}\n   理由: ${step.reasoning}';
    }).join('\n');

    return '''
## **战术剧本：$name**

**核心目标：** $coreGoal

**战术描述：**
$description

**执行步骤：**
$stepsText

**关键话术库（可参考使用）：**
${keyPhrases.asMap().entries.map((e) => '${e.key + 1}. "${e.value}"').join('\n')}

**风险提示：**
${risks.asMap().entries.map((e) => '- ${e.value}').join('\n')}

**成功标志：** $successCriteria
''';
  }
}

/// 剧本步骤
class PlaybookStep {
  /// 阶段（'night' | 'day' | 'vote'）
  final String phase;

  /// 行动描述
  final String action;

  /// 行动理由
  final String reasoning;

  /// 示例发言（可选）
  final List<String>? exampleSpeech;

  const PlaybookStep({
    required this.phase,
    required this.action,
    required this.reasoning,
    this.exampleSpeech,
  });
}
