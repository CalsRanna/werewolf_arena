import 'package:openai_dart/openai_dart.dart';
import 'package:werewolf_arena/engine/game_engine_logger.dart';
import 'package:werewolf_arena/engine/playbook/playbook.dart';
import 'package:werewolf_arena/engine/playbook/playbook_library.dart';
import 'package:werewolf_arena/engine/reasoning/reasoning_context.dart';
import 'package:werewolf_arena/engine/reasoning/reasoning_step.dart';

/// 剧本选择步骤（简化版）
///
/// 从剧本库中选择最适合当前场景的战术剧本
/// 当前实现：本地选择，不调用LLM（快速集成）
/// 未来优化：后续可升级为LLM选择
class PlaybookSelectionStep extends ReasoningStep {
  @override
  String get name => 'playbook_selection';

  @override
  String get description => '选择合适的战术剧本';

  @override
  Future<ReasoningContext> execute(
    ReasoningContext context,
    OpenAIClient client,
  ) async {
    GameEngineLogger.instance.d('[剧本选择] 开始选择...');

    final player = context.player;
    final state = context.state;

    // 1. 从剧本库获取推荐列表
    final recommendedPlaybooks = PlaybookLibrary.recommend(
      state: state,
      player: player,
    );

    // 2. 选择剧本（当前策略：选择第一个推荐，或不使用剧本）
    final Playbook? selectedPlaybook;
    if (recommendedPlaybooks.isNotEmpty) {
      selectedPlaybook = recommendedPlaybooks.first;
    } else {
      selectedPlaybook = null;
    }

    // 3. 存入上下文
    context.setStepOutput('selected_playbook', selectedPlaybook);

    // 4. 记录到思考链
    if (selectedPlaybook != null) {
      context.appendThought('''
[步骤4: 剧本选择]
选择的剧本: ${selectedPlaybook.name}
核心目标: ${selectedPlaybook.coreGoal}
''');
      GameEngineLogger.instance.d(
        '[剧本选择] 完成 - 选择了: ${selectedPlaybook.name}',
      );
    } else {
      context.appendThought('[步骤4: 剧本选择] 暂无合适的剧本');
      GameEngineLogger.instance.d('[剧本选择] 完成 - 无合适剧本');
    }

    return context;
  }
}
