import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';

/// 角色面具抽象基类
///
/// 理念：
/// - 基础性格（Persona）：AI的底层思考风格
/// - 角色面具（Mask）：AI在特定场景下的"表演风格"
///
/// 面具定义了AI在发言时的语气、风格、话术特征
abstract class RoleMask {
  /// 面具ID（唯一标识）
  String get id;

  /// 面具名称
  String get name;

  /// 面具描述
  String get description;

  /// 语言风格指导
  String get languageStyle;

  /// 语气特征
  String get tone;

  /// 典型话术示例
  List<String> get examplePhrases;

  /// 判断此面具是否适用于当前场景
  ///
  /// [state] 游戏状态
  /// [player] 当前玩家
  /// 返回 true 表示此面具适合当前场景
  bool isApplicable(GameState state, GamePlayer player);

  /// 生成完整的面具指导Prompt
  ///
  /// 用于在发言生成时指导LLM使用此面具的风格
  String toPrompt() {
    return '''
## **表演风格：$name**

**风格描述：** $description

**语气特征：** $tone

**语言风格：**
$languageStyle

**典型话术示例：**
${examplePhrases.asMap().entries.map((e) => '${e.key + 1}. "${e.value}"').join('\n')}

**重要提示：** 你的发言必须完全符合上述风格。这是你的"面具"，帮助你更好地达成目标。
''';
  }
}
