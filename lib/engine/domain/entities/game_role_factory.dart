import 'package:werewolf_arena/engine/domain/entities/game_role.dart';
import 'package:werewolf_arena/engine/domain/entities/guard_role.dart';
import 'package:werewolf_arena/engine/domain/entities/hunter_role.dart';
import 'package:werewolf_arena/engine/domain/entities/seer_role.dart';
import 'package:werewolf_arena/engine/domain/entities/villager_role.dart';
import 'package:werewolf_arena/engine/domain/entities/werewolf_role.dart';
import 'package:werewolf_arena/engine/domain/entities/witch_role.dart';
import 'package:werewolf_arena/engine/domain/enums/role_type.dart';

/// 角色工厂类
class GameRoleFactory {
  static GameRole createRole(String roleId) {
    switch (roleId) {
      case 'villager':
        return VillagerRole();
      case 'werewolf':
        return WerewolfRole();
      case 'seer':
        return SeerRole();
      case 'witch':
        return WitchRole();
      case 'hunter':
        return HunterRole();
      case 'guard':
        return GuardRole();
      default:
        throw ArgumentError('Unknown role: $roleId');
    }
  }

  /// 根据角色类型创建角色实例
  static GameRole createRoleFromType(RoleType roleType) {
    switch (roleType) {
      case RoleType.villager:
        return VillagerRole();
      case RoleType.werewolf:
        return WerewolfRole();
      case RoleType.seer:
        return SeerRole();
      case RoleType.witch:
        return WitchRole();
      case RoleType.hunter:
        return HunterRole();
      case RoleType.guard:
        return GuardRole();
    }
  }

  static List<GameRole> createRolesFromConfig(Map<String, int> roleConfig) {
    final roles = <GameRole>[];
    roleConfig.forEach((roleId, count) {
      for (int i = 0; i < count; i++) {
        roles.add(createRole(roleId));
      }
    });
    return roles;
  }
}
