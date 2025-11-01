import 'package:openai_dart/openai_dart.dart';
import 'package:werewolf_arena/engine/game_engine_logger.dart';
import 'package:werewolf_arena/engine/mask/mask_library.dart';
import 'package:werewolf_arena/engine/mask/role_mask.dart';
import 'package:werewolf_arena/engine/reasoning/reasoning_context.dart';
import 'package:werewolf_arena/engine/reasoning/reasoning_step.dart';

/// 面具选择步骤（简化版）
///
/// 从面具库中选择最适合当前场景的面具
/// 当前实现：本地选择，不调用LLM（快速集成）
/// TODO: 后续可升级为LLM选择
class MaskSelectionStep extends ReasoningStep {
  @override
  String get name => 'mask_selection';

  @override
  String get description => '选择合适的角色面具';

  @override
  Future<ReasoningContext> execute(
    ReasoningContext context,
    OpenAIClient client,
  ) async {
    GameEngineLogger.instance.d('[面具选择] 开始选择...');

    final player = context.player;
    final state = context.state;

    // 1. 从面具库获取推荐列表
    final recommendedMasks = MaskLibrary.recommend(
      state: state,
      player: player,
    );

    // 2. 选择面具（当前策略：选择第一个推荐，或使用默认）
    final RoleMask selectedMask;
    if (recommendedMasks.isNotEmpty) {
      selectedMask = recommendedMasks.first;
    } else {
      selectedMask = MaskLibrary.getDefault();
    }

    // 3. 存入上下文
    context.setStepOutput('selected_mask', selectedMask);

    // 4. 记录到思考链
    context.appendThought('''
[步骤5: 面具选择]
选择的面具: ${selectedMask.name}
面具描述: ${selectedMask.description}
''');

    GameEngineLogger.instance.d(
      '[面具选择] 完成 - 选择了: ${selectedMask.name}',
    );

    return context;
  }
}
