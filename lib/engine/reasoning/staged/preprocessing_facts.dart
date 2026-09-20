import 'package:werewolf_arena/engine/event/game_event.dart';
import 'package:werewolf_arena/engine/event/game_start_event.dart';
import 'package:werewolf_arena/engine/event/log_event.dart';
import 'package:werewolf_arena/engine/event/order_event.dart';
import 'package:werewolf_arena/engine/event/system_event.dart';
import 'package:werewolf_arena/engine/player/ai_player.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/reasoning/reasoning_context.dart';

/// 预处理的一次输出里"必须由模型判断"的那部分。
///
/// 对应 WorldState 里三类内容中的第二类。事实类不在这里（代码直接拼），
/// 自由文本也不在这里（生成模型负责，Jev 这类判定模型不生成文本）。
class PreprocessingJudgments {
  /// 玩家名 -> 推测角色（如 "3号玩家" -> "狼人"）
  final Map<String, String> roleByPlayer;

  /// 玩家名 -> 推测置信度（0-100）
  final Map<String, int> confidenceByPlayer;

  /// 盟友关系：玩家名 -> 盟友玩家名列表
  final Map<String, List<String>> alliances;

  /// 敌对关系：玩家名 -> 敌对玩家名列表
  final Map<String, List<String>> hostilities;

  /// 我最信任的玩家（最多 3 个）
  final List<String> mostTrusted;

  /// 我最怀疑的玩家（最多 3 个）
  final List<String> mostSuspicious;

  const PreprocessingJudgments({
    this.roleByPlayer = const {},
    this.confidenceByPlayer = const {},
    this.alliances = const {},
    this.hostilities = const {},
    this.mostTrusted = const [],
    this.mostSuspicious = const [],
  });

  static const PreprocessingJudgments empty = PreprocessingJudgments();
}

/// 判定提供方。真实实现走 System One（Jev）；测试用假实现即可，
/// 因此预处理阶段不直接依赖任何 HTTP 客户端。
abstract class JudgmentProvider {
  Future<PreprocessingJudgments> judge({
    required String state,
    required List<String> players,
  });
}

/// 预处理的事实层：能用代码算出来的，一律不进模型。
///
/// 拆分依据（读 PreprocessingStage 与原 user prompt 得到）：
///   事实类  self_info 全部字段、存活/出局名单、事件历史 —— 输入里本就有，让模型抄写
///          既多花钱，又引入"抄错自己角色"这类新错误。
///   判定类  每个玩家的推测角色/置信度、盟友敌对 —— 答案空间可枚举。
///   文本类  局势总结、核心矛盾、发言摘要、事件描述 —— 判定模型不生成文本。
class PreprocessingFacts {
  PreprocessingFacts._();

  /// 纯流程类事件：它们只说明流程走到哪一步，不构成身份线索。
  ///
  /// OrderEvent 尤其要注意——它在每回合开局就创建且对所有人可见
  /// （"第N天，发言顺序为…"），若当成信息，会让"无信息阶段"永远判为有信息。
  static bool isProcedural(GameEvent event) =>
      event is GameStartEvent ||
      event is SystemEvent ||
      event is LogEvent ||
      event is OrderEvent;

  /// 历史里是否存在真正可判断的内容。
  ///
  /// 这是"这一步值不值得做"的判据：第 1 夜所有行动都发生在公开信息产生之前，
  /// 此时做完整整理只会得到"未知(0)""暂无冲突"这类占位输出。
  static bool hasInformativeHistory(List<GameEvent> events) => events.any(
    (event) => !isProcedural(event) && event.toNarrative().trim().isNotEmpty,
  );

  /// 渲染可读历史。用 toNarrative()——所有事件子类都实现了它，
  /// toString() 只会给出 `GameEvent(<id>)`。
  static String renderHistory(List<GameEvent> events, {int limit = 20}) {
    final informative = events.where(
      (event) => event.toNarrative().trim().isNotEmpty,
    );
    final buffer = StringBuffer();
    for (final event in informative.take(limit)) {
      buffer.writeln('- [第${event.day}天] ${event.toNarrative()}');
    }
    return buffer.toString();
  }

  /// 去掉给生成模型看的 JSON 格式说明那一段。
  ///
  /// 判定模型要的是"事实 + 问题"，格式说明只会稀释 state
  /// （Jev 对无关内容敏感，官方文档明确称其为 context rot）。
  static String stripTaskSection(String prompt) {
    final cut = prompt.indexOf('# 任务');
    return (cut > 0 ? prompt.substring(0, cut) : prompt).trim();
  }

  /// 用代码拼出 WorldState 的事实部分。
  ///
  /// 不发任何模型调用。[judgments] 为 [PreprocessingJudgments.empty] 时，
  /// 得到的 WorldState 只有事实，没有推测——这正是"无信息阶段"应有的结果。
  static WorldState build({
    required GamePlayer player,
    required List<GamePlayer> allPlayers,
    required List<GamePlayer> alivePlayers,
    PreprocessingJudgments judgments = PreprocessingJudgments.empty,
  }) {
    final isWolf = player.role.id == 'werewolf';

    return WorldState(
      selfInfo: PlayerSelfInfo(
        name: player.name,
        number: player.name.replaceAll('号玩家', ''),
        role: player.role.name,
        faction: isWolf ? '狼人' : '好人',
        teammates: isWolf
            ? allPlayers
                  .where((p) => p.role.id == 'werewolf' && p.id != player.id)
                  .map((p) => p.name)
                  .toList()
            : const [],
        secretKnowledge: _secretKnowledge(player),
      ),
      otherPlayers: [
        for (final other in allPlayers.where((p) => p.id != player.id))
          OtherPlayerInfo(
            name: other.name,
            isAlive: alivePlayers.any((a) => a.id == other.id),
            estimatedRole: judgments.roleByPlayer[other.name],
            estimatedConfidence: judgments.confidenceByPlayer[other.name],
            // 发言摘要属生成类，判定层不产出
            keySpeechSummary: const [],
          ),
      ],
      // 事件描述是自由文本；事实层的等价物是 renderHistory()，直接进提示词。
      keyEvents: const [],
      socialRelationships: SocialRelationships(
        alliances: judgments.alliances,
        hostilities: judgments.hostilities,
        myMostTrusted: judgments.mostTrusted,
        myMostSuspicious: judgments.mostSuspicious,
      ),
      situationSummary: '',
      coreConflict: null,
    );
  }

  static Map<String, dynamic> _secretKnowledge(GamePlayer player) {
    if (player is! AIPlayer) return const {};
    // AIPlayer.workingMemory 是可空的：非 AI 驱动或尚未初始化的玩家没有记忆。
    final secret = player.workingMemory?.secretKnowledge;
    if (secret == null) return const {};
    return {
      if (secret.inspectionResults.isNotEmpty)
        'inspection_results': secret.inspectionResults,
      if (secret.protectionHistory.isNotEmpty)
        'protection_history': secret.protectionHistory,
      ...secret.otherSecrets,
    };
  }
}
