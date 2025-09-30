import '../utils/random_helper.dart';
import '../player/player.dart';
import '../game/game_state.dart';
import '../game/game_action.dart';

/// 角色类型
enum RoleType {
  werewolf,  // 狼人
  villager,  // 村民
  god,       // 神职
}

/// 角色阵营
enum RoleAlignment {
  good,      // 好人阵营
  evil,      // 狼人阵营
  neutral,   // 中立阵营
}

/// 技能类
abstract class Skill {
  final String skillId;
  final String name;
  final String description;
  final int cooldown;
  final int maxUses;
  final bool isActive;
  final bool requiresTarget;

  Skill({
    required this.skillId,
    required this.name,
    required this.description,
    this.cooldown = 0,
    this.maxUses = -1, // -1 表示无限使用
    this.isActive = true,
    this.requiresTarget = false,
  });

  bool canUse(Player player, GameState state) {
    return player.isAlive &&
           (maxUses == -1 || player.getSkillUses(skillId) < maxUses) &&
           (cooldown == 0 || player.getSkillCooldown(skillId) == 0);
  }

  void use(Player player, {Player? target, GameState? state}) {
    player.useSkill(skillId);
  }

  String getUsageInfo(Player player) {
    final uses = maxUses == -1 ? '无限' : '${maxUses - player.getSkillUses(skillId)}/$maxUses';
    final cd = player.getSkillCooldown(skillId);
    final cooldownText = cd > 0 ? ' (冷却: $cd)' : '';
    return '$name: $uses$cooldownText';
  }
}

/// 角色抽象类
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
  List<GameAction> getAvailableActions(Player player, GameState state) {
    return [];
  }

  bool canUseSkill(Skill skill, Player player, GameState state) {
    return skill.canUse(player, state);
  }

  void useSkill(Skill skill, Player player, {Player? target, GameState? state}) {
    skill.use(player, target: target, state: state);
  }

  String getNightActionDescription() {
    return '';
  }

  String getDayActionDescription() {
    return '';
  }

  // Private data management for role-specific state
  Map<String, dynamic> _privateData = {};

  T? getPrivateData<T>(String key) {
    return _privateData[key] as T?;
  }

  void setPrivateData<T>(String key, T value) {
    _privateData[key] = value;
  }

  String getRoleInfo() {
    return '''
$name ($type)
阵营: $alignment
描述: $description
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

  @override
  List<GameAction> getAvailableActions(Player player, GameState state) {
    final actions = <GameAction>[];

    if (state.isDay || state.isVoting) {
      // 白天可以发言和投票
      actions.add(SpeakAction(actor: player, message: ''));
    }

    if (state.isVoting) {
      // 投票阶段可以投票
      final alivePlayers = state.alivePlayers.where((p) => p != player).toList();
      actions.addAll(alivePlayers.map((target) => VoteAction(
        actor: player,
        target: target,
      )));
    }

    return actions;
  }
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
  List<GameAction> getAvailableActions(Player player, GameState state) {
    if (!state.isNight) return [];

    final actions = <GameAction>[];
    final alivePlayers = state.alivePlayers.where((p) => !p.role.isWerewolf).toList();

    actions.addAll(alivePlayers.map((target) => KillAction(
      actor: player,
      target: target,
    )));

    return actions;
  }

  @override
  String getNightActionDescription() {
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
  List<GameAction> getAvailableActions(Player player, GameState state) {
    if (!state.isNight) return [];

    final actions = <GameAction>[];
    final otherPlayers = state.alivePlayers.where((p) => p != player).toList();

    actions.addAll(otherPlayers.map((target) => InvestigateAction(
      actor: player,
      target: target,
    )));

    return actions;
  }

  @override
  String getNightActionDescription() {
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
  List<GameAction> getAvailableActions(Player player, GameState state) {
    if (!state.isNight) return [];

    final actions = <GameAction>[];
    final tonightVictim = getTonightVictim(state);

    // 解药
    if (hasAntidote && tonightVictim != null) {
      actions.add(HealAction(
        actor: player,
        target: tonightVictim,
      ));
    }

    // 毒药
    if (hasPoison) {
      final otherPlayers = state.alivePlayers.where((p) => p != player).toList();
      actions.addAll(otherPlayers.map((target) => PoisonAction(
        actor: player,
        target: target,
      )));
    }

    return actions;
  }

  @override
  String getNightActionDescription() {
    final parts = <String>[];
    if (hasAntidote) parts.add('使用解药');
    if (hasPoison) parts.add('使用毒药');
    return parts.isNotEmpty ? parts.join(' 或 ') : '无可用技能';
  }

  bool get hasAntidote => getPrivateData('has_antidote') == true;
  bool get hasPoison => getPrivateData('has_poison') == true;

  Player? getTonightVictim(GameState state) {
    return getPrivateData('tonight_victim');
  }

  void useAntidote() {
    setPrivateData('has_antidote', false);
  }

  void usePoison() {
    setPrivateData('has_poison', false);
  }

  void setTonightVictim(Player? victim) {
    setPrivateData('tonight_victim', victim);
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
  String getNightActionDescription() {
    return '无主动技能，死亡时可开枪';
  }

  bool canShoot(GameState state) {
    final player = state.players.firstWhere((p) => p.role == this);
    return !player.isAlive && getPrivateData('has_shot') != true;
  }

  void shoot() {
    setPrivateData('has_shot', true);
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
  List<GameAction> getAvailableActions(Player player, GameState state) {
    if (!state.isNight) return [];

    final actions = <GameAction>[];
    final otherPlayers = state.alivePlayers.where((p) => p != player).toList();
    final lastGuarded = getPrivateData('last_guarded');

    for (final target in otherPlayers) {
      if (target != lastGuarded) {
        actions.add(ProtectAction(
          actor: player,
          target: target,
        ));
      }
    }

    return actions;
  }

  @override
  String getNightActionDescription() {
    return '选择一名玩家守护（不能连续两晚守护同一人）';
  }

  Player? get lastGuarded => getPrivateData('last_guarded');

  void setLastGuarded(Player? player) {
    setPrivateData('last_guarded', player);
  }
}

// Skill implementations
class KillSkill extends Skill {
  KillSkill() : super(
    skillId: 'kill',
    name: '击杀',
    description: '击杀一名玩家',
    cooldown: 0,
    maxUses: -1,
    requiresTarget: true,
  );
}

class InvestigateSkill extends Skill {
  InvestigateSkill() : super(
    skillId: 'investigate',
    name: '查验',
    description: '查验一名玩家身份',
    cooldown: 0,
    maxUses: -1,
    requiresTarget: true,
  );
}

class HealSkill extends Skill {
  HealSkill() : super(
    skillId: 'heal',
    name: '解药',
    description: '救活今晚被击杀的玩家',
    cooldown: 0,
    maxUses: 1,
    requiresTarget: true,
  );
}

class PoisonSkill extends Skill {
  PoisonSkill() : super(
    skillId: 'poison',
    name: '毒药',
    description: '毒杀一名玩家',
    cooldown: 0,
    maxUses: 1,
    requiresTarget: true,
  );
}

class HunterShootSkill extends Skill {
  HunterShootSkill() : super(
    skillId: 'hunter_shoot',
    name: '开枪',
    description: '死亡时开枪带走一名玩家',
    cooldown: 0,
    maxUses: 1,
    requiresTarget: true,
  );
}

class ProtectSkill extends Skill {
  ProtectSkill() : super(
    skillId: 'protect',
    name: '守护',
    description: '守护一名玩家免受狼人击杀',
    cooldown: 0,
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

  static Role createByType(RoleType type) {
    switch (type) {
      case RoleType.villager:
        return VillagerRole();
      case RoleType.werewolf:
        return WerewolfRole();
      case RoleType.god:
        // Return a random god role
        final godRoles = ['seer', 'witch', 'hunter', 'guard'];
        return createRole(godRoles[RandomHelper().nextInt(godRoles.length)]);
    }
  }

  static List<String> getAllRoleIds() {
    return ['villager', 'werewolf', 'seer', 'witch', 'hunter', 'guard'];
  }

  static List<RoleType> getAllRoleTypes() {
    return RoleType.values;
  }
}