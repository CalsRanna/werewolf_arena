import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/mask/aggressive_attacker_mask.dart';
import 'package:werewolf_arena/engine/mask/authoritative_leader_mask.dart';
import 'package:werewolf_arena/engine/mask/calm_analyst_mask.dart';
import 'package:werewolf_arena/engine/mask/confused_novice_mask.dart';
import 'package:werewolf_arena/engine/mask/follower_mask.dart';
import 'package:werewolf_arena/engine/mask/instigator_mask.dart';
import 'package:werewolf_arena/engine/mask/peacemaker_mask.dart';
import 'package:werewolf_arena/engine/mask/role_mask.dart';
import 'package:werewolf_arena/engine/mask/scapegoater_mask.dart';
import 'package:werewolf_arena/engine/mask/victimized_good_person_mask.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';

/// 面具库
///
/// 管理所有可用的角色面具，提供面具推荐功能
class MaskLibrary {
  /// 所有可用的面具
  static final List<RoleMask> allMasks = [
    // 进攻型面具
    AuthoritativeLeaderMask(), // 强势领袖
    AggressiveAttackerMask(), // 激进攻击者

    // 防守型面具
    VictimizedGoodPersonMask(), // 委屈好人
    ScapegoaterMask(), // 甩锅者

    // 理性型面具
    CalmAnalystMask(), // 冷静分析师
    PeacemakerMask(), // 和事佬

    // 低调型面具
    ConfusedNoviceMask(), // 迷茫新手
    FollowerMask(), // 跟风者

    // 挑拨型面具
    InstigatorMask(), // 煽动者
  ];

  /// 根据场景推荐合适的面具
  ///
  /// [state] 游戏状态
  /// [player] 当前玩家
  /// 返回适用的面具列表（按优先级排序）
  static List<RoleMask> recommend({
    required GameState state,
    required GamePlayer player,
  }) {
    return allMasks
        .where((mask) => mask.isApplicable(state, player))
        .toList();
  }

  /// 根据ID获取面具
  ///
  /// [id] 面具ID
  /// 返回对应的面具，如果不存在则返回null
  static RoleMask? getById(String id) {
    try {
      return allMasks.firstWhere((mask) => mask.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 获取默认面具
  ///
  /// 当没有合适的面具时使用
  static RoleMask getDefault() {
    return VictimizedGoodPersonMask(); // 委屈好人是最通用的面具
  }
}
