import '../player/player.dart';
import '../game/game_state.dart';
import '../game/game_event.dart';

/// Role types
enum RoleType {
  werewolf,  // Werewolf
  villager,  // Villager
  god,       // God role
}

/// Role alignments
enum RoleAlignment {
  good,      // Good side
  evil,      // Werewolf side
  neutral,   // Neutral side
}

/// Skill class
abstract class Skill {
  final String skillId;
  final String name;
  final String description;
  final int maxUses;
  final bool isActive;
  final bool requiresTarget;

  Skill({
    required this.skillId,
    required this.name,
    required this.description,
    this.maxUses = -1, // -1 means unlimited uses
    this.isActive = true,
    this.requiresTarget = false,
  });

  bool canUse(Player player, GameState state) {
    return player.isAlive &&
           (maxUses == -1 || player.getSkillUses(skillId) < maxUses);
  }

  void use(Player player, {Player? target, GameState? state}) {
    player.useSkill(skillId);
  }

  String getUsageInfo(Player player) {
    final uses = maxUses == -1 ? 'Unlimited' : '${maxUses - player.getSkillUses(skillId)}/$maxUses';
    return '$name: $uses';
  }
}

/// Abstract role class
abstract class Role {
  final String roleId;
  final String name;
  final RoleType type;
  final RoleAlignment alignment;
  final String description;
  final List<Skill> skills;
  final bool isUnique;

  Role({
    required this.roleId,
    required this.name,
    required this.type,
    required this.alignment,
    required this.description,
    this.skills = const [],
    this.isUnique = false,
  });

  // Getters
  bool get isWerewolf => type == RoleType.werewolf;
  bool get isVillager => type == RoleType.villager;
  bool get isGod => type == RoleType.god;
  bool get isGood => alignment == RoleAlignment.good;
  bool get isEvil => alignment == RoleAlignment.evil;

  // Virtual methods
  // Note: getAvailableActions has been removed.
  // Use Player.createXEvent() methods instead to create events.

  String getNightActionDescription(GameState state) {
    return '';
  }

  String getDayActionDescription() {
    return '';
  }

  // Private data management for role-specific state
  final Map<String, dynamic> _privateData = <String, dynamic>{};

  T? getPrivateData<T>(String key) {
    return _privateData[key] as T?;
  }

  void setPrivateData<T>(String key, T value) {
    _privateData[key] = value;
  }

  String getRoleInfo() {
    return '''
$name ($type)
Alignment: $alignment
Description: $description
技能: ${skills.map((s) => s.name).join(', ')}
''';
  }

  Map<String, dynamic> toJson() {
    return {
      'roleId': roleId,
      'name': name,
      'type': type.name,
      'alignment': alignment.name,
      'description': description,
      'skills': skills.map((s) => s.skillId).toList(),
      'isUnique': isUnique,
    };
  }
}

/// 村民角色
class VillagerRole extends Role {
  VillagerRole() : super(
    roleId: 'villager',
    name: '村民',
    type: RoleType.villager,
    alignment: RoleAlignment.good,
    description: '普通村民，没有特殊技能，通过推理和投票找出狼人',
    isUnique: false,
  );
}

/// 狼人角色
class WerewolfRole extends Role {
  WerewolfRole() : super(
    roleId: 'werewolf',
    name: '狼人',
    type: RoleType.werewolf,
    alignment: RoleAlignment.evil,
    description: '每晚可以击杀一名玩家，狼人之间相互认识',
    skills: [
      KillSkill(),
    ],
    isUnique: false,
  );

  @override
  String getNightActionDescription(GameState state) {
    return '选择一名玩家击杀';
  }
}

/// 预言家角色
class SeerRole extends Role {
  SeerRole() : super(
    roleId: 'seer',
    name: '预言家',
    type: RoleType.god,
    alignment: RoleAlignment.good,
    description: '每晚可以查验一名玩家的身份',
    skills: [
      InvestigateSkill(),
    ],
    isUnique: true,
  );

  @override
  String getNightActionDescription(GameState state) {
    return '选择一名玩家查验身份';
  }
}

/// 女巫角色
class WitchRole extends Role {
  WitchRole() : super(
    roleId: 'witch',
    name: '女巫',
    type: RoleType.god,
    alignment: RoleAlignment.good,
    description: '拥有一瓶解药和一瓶毒药',
    skills: [
      HealSkill(),
      PoisonSkill(),
    ],
    isUnique: true,
  );

  @override
  String getNightActionDescription(GameState state) {
    final parts = <String>[];
    if (hasAntidote(state)) parts.add('使用解药');
    if (hasPoison(state)) parts.add('使用毒药');
    return parts.isNotEmpty ? parts.join(' 或 ') : '无可用技能';
  }

  bool hasAntidote(GameState state) {
    // Check if antidote has been used by looking at heal events
    final healEvents = state.eventHistory.whereType<WitchHealEvent>()
        .where((e) => e.initiator?.role == this).toList();
    return healEvents.isEmpty; // Has antidote if never used
  }

  bool hasPoison(GameState state) {
    // Check if poison has been used by looking at poison events
    final poisonEvents = state.eventHistory.whereType<WitchPoisonEvent>()
        .where((e) => e.initiator?.role == this).toList();
    return poisonEvents.isEmpty; // Has poison if never used
  }

  Player? getTonightVictim(GameState state) {
    return state.tonightVictim;
  }
}

/// 猎人角色
class HunterRole extends Role {
  HunterRole() : super(
    roleId: 'hunter',
    name: '猎人',
    type: RoleType.god,
    alignment: RoleAlignment.good,
    description: '死亡时可以开枪带走一名玩家',
    skills: [
      HunterShootSkill(),
    ],
    isUnique: true,
  );

  @override
  String getNightActionDescription(GameState state) {
    return '无主动技能，死亡时可开枪';
  }

  bool canShoot(GameState state) {
    final player = state.players.firstWhere((p) => p.role == this);
    // Check if hunter has already shot by looking at shoot events
    final shootEvents = state.eventHistory.whereType<HunterShootEvent>()
        .where((e) => e.initiator?.role == this).toList();
    return !player.isAlive && shootEvents.isEmpty; // Can shoot if dead and never shot
  }
}

/// 守卫角色
class GuardRole extends Role {
  GuardRole() : super(
    roleId: 'guard',
    name: '守卫',
    type: RoleType.god,
    alignment: RoleAlignment.good,
    description: '每晚可以守护一名玩家，但不能连续两晚守护同一人',
    skills: [
      ProtectSkill(),
    ],
    isUnique: true,
  );

  @override
  String getNightActionDescription(GameState state) {
    return '选择一名玩家守护（不能连续两晚守护同一人）';
  }

  Player? getLastGuarded(GameState state) {
    // Find the most recent protect event by this guard
    final protectEvents = state.eventHistory
        .whereType<GuardProtectEvent>()
        .where((e) => e.initiator?.role == this)
        .toList();

    if (protectEvents.isEmpty) return null;

    // Sort by timestamp and get the most recent one
    protectEvents.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return protectEvents.first.target;
  }

  /// 获取守卫可以守护的玩家列表（排除上次守护的玩家）
  List<Player> getAvailableTargets(GameState state) {
    final allPlayers = state.players.where((p) => p.isAlive).toList();
    final lastGuarded = getLastGuarded(state);

    if (lastGuarded == null) {
      return allPlayers;
    }

    // 排除上次守护的玩家
    return allPlayers.where((p) => p.playerId != lastGuarded.playerId).toList();
  }
}

// Skill implementations
class KillSkill extends Skill {
  KillSkill() : super(
    skillId: 'kill',
    name: '击杀',
    description: '击杀一名玩家',
    maxUses: -1,
    requiresTarget: true,
  );
}

class InvestigateSkill extends Skill {
  InvestigateSkill() : super(
    skillId: 'investigate',
    name: '查验',
    description: '查验一名玩家身份',
    maxUses: -1,
    requiresTarget: true,
  );
}

class HealSkill extends Skill {
  HealSkill() : super(
    skillId: 'heal',
    name: '解药',
    description: '救活今晚被击杀的玩家',
    maxUses: 1,
    requiresTarget: true,
  );
}

class PoisonSkill extends Skill {
  PoisonSkill() : super(
    skillId: 'poison',
    name: '毒药',
    description: '毒杀一名玩家',
    maxUses: 1,
    requiresTarget: true,
  );
}

class HunterShootSkill extends Skill {
  HunterShootSkill() : super(
    skillId: 'hunter_shoot',
    name: '开枪',
    description: '死亡时开枪带走一名玩家',
    maxUses: 1,
    requiresTarget: true,
  );
}

class ProtectSkill extends Skill {
  ProtectSkill() : super(
    skillId: 'protect',
    name: '守护',
    description: '守护一名玩家免受狼人击杀',
    maxUses: -1,
    requiresTarget: true,
  );
}

// Factory for creating roles
class RoleFactory {
  static Role createRole(String roleId) {
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
        throw ArgumentError('Unknown role type: $roleId');
    }
  }
}