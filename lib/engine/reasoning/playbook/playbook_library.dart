import 'package:werewolf_arena/engine/game_context.dart';
import 'package:werewolf_arena/engine/reasoning/playbook/guard_protect_playbook.dart';
import 'package:werewolf_arena/engine/reasoning/playbook/playbook.dart';
import 'package:werewolf_arena/engine/reasoning/playbook/seer_reveal_playbook.dart';
import 'package:werewolf_arena/engine/reasoning/playbook/villager_block_knife_playbook.dart';
import 'package:werewolf_arena/engine/reasoning/playbook/werewolf_charge_playbook.dart';
import 'package:werewolf_arena/engine/reasoning/playbook/werewolf_hook_playbook.dart';
import 'package:werewolf_arena/engine/reasoning/playbook/werewolf_jump_seer_playbook.dart';
import 'package:werewolf_arena/engine/reasoning/playbook/werewolf_kill_god_playbook.dart';
import 'package:werewolf_arena/engine/reasoning/playbook/witch_hide_antidote_playbook.dart';
import 'package:werewolf_arena/engine/reasoning/playbook/witch_use_poison_playbook.dart';
import 'package:werewolf_arena/engine/reasoning/playbook/seer_campaign_playbook.dart';
import 'package:werewolf_arena/engine/reasoning/playbook/werewolf_jump_sheriff_playbook.dart';
import 'package:werewolf_arena/engine/reasoning/playbook/villager_campaign_playbook.dart';
import 'package:werewolf_arena/engine/reasoning/playbook/witch_hunter_avoid_sheriff_playbook.dart';
import 'package:werewolf_arena/engine/reasoning/playbook/sheriff_badge_flow_playbook.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';

/// 剧本库
///
/// 管理所有可用的战术剧本，提供剧本推荐功能
class PlaybookLibrary {
  /// 所有可用的剧本
  static final List<Playbook> allPlaybooks = [
    // 狼人剧本
    WerewolfJumpSeerPlaybook(), // 狼人悍跳预言家
    WerewolfJumpSheriffPlaybook(), // 狼人抢警徽
    WerewolfHookPlaybook(), // 狼人倒钩
    WerewolfKillGodPlaybook(), // 狼人刀神职
    WerewolfChargePlaybook(), // 狼人冲锋
    // 预言家剧本
    SeerRevealPlaybook(), // 预言家起跳
    SeerCampaignPlaybook(), // 预言家竞选警长
    // 女巫剧本
    WitchHideAntidotePlaybook(), // 女巫藏药
    WitchUsePoisonPlaybook(), // 女巫用毒
    WitchHunterAvoidSheriffPlaybook(), // 女巫/猎人避让警徽
    // 守卫剧本
    GuardProtectPlaybook(), // 守卫守护
    // 村民剧本
    VillagerBlockKnifePlaybook(), // 村民假冲锋
    VillagerCampaignPlaybook(), // 平民竞选警长
    // 警徽流剧本
    SheriffBadgeFlowPlaybook(), // 警徽流传递策略
  ];

  /// 为玩家推荐合适的剧本
  ///
  /// [state] 游戏状态
  /// [player] 当前玩家
  /// 返回适用的剧本列表（按优先级排序）
  static List<Playbook> recommend({
    required GameContext state,
    required GamePlayer player,
  }) {
    return allPlaybooks
        .where(
          (playbook) =>
              playbook.applicableRoles.contains(player.role.id) &&
              playbook.canActivate(state, player),
        )
        .toList();
  }

  /// 根据ID获取剧本
  ///
  /// [id] 剧本ID
  /// 返回对应的剧本，如果不存在则返回null
  static Playbook? getById(String id) {
    try {
      return allPlaybooks.firstWhere((playbook) => playbook.id == id);
    } catch (_) {
      return null;
    }
  }
}
