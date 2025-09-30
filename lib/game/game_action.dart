import 'game_state.dart';
import '../player/player.dart';
import '../player/role.dart';

/// 动作技能类
class ActionSkill {
  final String skillId;
  final String name;
  final String description;
  final String type;

  ActionSkill({
    required this.skillId,
    required this.name,
    required this.description,
    required this.type,
  });
}

/// 击杀技能
class KillSkill extends ActionSkill {
  KillSkill()
      : super(
          skillId: 'kill_skill',
          name: '击杀',
          description: '狼人夜晚击杀技能',
          type: 'night_action',
        );
}

/// 保护技能
class ProtectSkill extends ActionSkill {
  ProtectSkill()
      : super(
          skillId: 'protect_skill',
          name: '守护',
          description: '守卫守护技能',
          type: 'night_action',
        );
}

/// 查验技能
class InvestigateSkill extends ActionSkill {
  InvestigateSkill()
      : super(
          skillId: 'investigate_skill',
          name: '查验',
          description: '预言家查验技能',
          type: 'night_action',
        );
}

/// 治疗技能
class HealSkill extends ActionSkill {
  HealSkill()
      : super(
          skillId: 'heal_skill',
          name: '救治',
          description: '女巫救治技能',
          type: 'night_action',
        );
}

/// 毒杀技能
class PoisonSkill extends ActionSkill {
  PoisonSkill()
      : super(
          skillId: 'poison_skill',
          name: '毒杀',
          description: '女巫毒杀技能',
          type: 'night_action',
        );
}

/// 猎人开枪技能
class HunterShootSkill extends ActionSkill {
  HunterShootSkill()
      : super(
          skillId: 'hunter_shoot_skill',
          name: '开枪',
          description: '猎人开枪技能',
          type: 'death_action',
        );
}

/// 动作类型
enum ActionType {
  kill, // 击杀
  protect, // 保护
  investigate, // 查验
  heal, // 救治
  poison, // 毒杀
  vote, // 投票
  speak, // 发言
  useSkill, // 使用技能
}

/// 游戏动作基类
abstract class GameAction {
  final String actionId;
  final Player actor;
  final Player? target;
  final ActionType type;
  final ActionSkill? skill;
  final Map<String, dynamic> parameters;
  final String description;

  GameAction({
    required this.actor,
    required this.type,
    this.target,
    this.skill,
    this.parameters = const {},
    String? description,
  })  : actionId = 'action_${DateTime.now().millisecondsSinceEpoch}',
        description = description ?? _generateDescription(type, actor, target);

  static String _generateDescription(
      ActionType type, Player actor, Player? target) {
    final actionNames = {
      ActionType.kill: '击杀',
      ActionType.protect: '保护',
      ActionType.investigate: '查验',
      ActionType.heal: '救治',
      ActionType.poison: '毒杀',
      ActionType.vote: '投票',
      ActionType.speak: '发言',
      ActionType.useSkill: '使用技能',
    };

    final actionName = actionNames[type] ?? type.name;
    if (target != null) {
      return '${actor.name} $actionName ${target.name}';
    } else {
      return '${actor.name} $actionName';
    }
  }

  /// 验证动作是否可以执行
  bool validate(GameState state) {
    // Basic validation
    if (!actor.isAlive) return false;

    // Check if actor can perform this action
    if (!actor.canPerformAction(this, state)) return false;

    // Check phase restrictions
    if (!_isValidPhase(state.currentPhase)) return false;

    // Check target validation
    if (target != null && !_isValidTarget(target!, state)) return false;

    return true;
  }

  /// 执行动作
  void execute(GameState state) {
    if (!validate(state)) {
      throw Exception('Invalid action: $description');
    }

    _performAction(state);
  }

  /// 子类实现具体动作逻辑
  void _performAction(GameState state);

  /// 检查是否在有效阶段
  bool _isValidPhase(GamePhase phase) {
    switch (type) {
      case ActionType.kill:
      case ActionType.protect:
      case ActionType.investigate:
      case ActionType.heal:
      case ActionType.poison:
        return phase == GamePhase.night;
      case ActionType.vote:
        return phase == GamePhase.voting;
      case ActionType.speak:
        return phase == GamePhase.day;
      case ActionType.useSkill:
        return true; // Skill-specific phase validation
    }
  }

  /// 检查目标是否有效
  bool _isValidTarget(Player target, GameState state) {
    if (!target.isAlive) return false;

    switch (type) {
      case ActionType.kill:
        return !target.role.isWerewolf; // Can't kill werewolves
      case ActionType.protect:
      case ActionType.investigate:
      case ActionType.heal:
      case ActionType.poison:
        return target.playerId != actor.playerId; // Can't target self
      case ActionType.vote:
        return target.playerId != actor.playerId; // Can't vote for self
      case ActionType.speak:
        return false; // Speak doesn't have a target
      case ActionType.useSkill:
        return true; // Skill-specific target validation
    }
  }

  /// 转换为游戏事件
  GameEvent toEvent() {
    return GameEvent(
      eventId:
          '${type.name}_${actor.playerId}_${DateTime.now().millisecondsSinceEpoch}',
      type: GameEventType.playerAction,
      description: description,
      initiator: actor,
      target: target,
      data: {
        'actionId': actionId,
        'type': type.name,
        'skill': skill?.skillId,
        'parameters': parameters,
      },
    );
  }

  @override
  String toString() {
    return description;
  }

  Map<String, dynamic> toJson() {
    return {
      'actionId': actionId,
      'actor': actor.playerId,
      'target': target?.playerId,
      'type': type.name,
      'skill': skill?.skillId,
      'parameters': parameters,
      'description': description,
    };
  }
}

/// 击杀动作
class KillAction extends GameAction {
  KillAction({
    required super.actor,
    required Player super.target,
  }) : super(
          type: ActionType.kill,
          skill: KillSkill(),
        );

  @override
  void _performAction(GameState state) {
    // Mark target for death (will be resolved at end of night)
    state.setTonightVictim(target);

    // Log the kill action
    state.skillUsed(actor, '击杀', target: target);
  }
}

/// 保护动作
class ProtectAction extends GameAction {
  ProtectAction({
    required super.actor,
    required Player super.target,
  }) : super(
          type: ActionType.protect,
          skill: ProtectSkill(),
        );

  @override
  void _performAction(GameState state) {
    state.setTonightProtected(target);

    if (actor.role is GuardRole) {
      (actor.role as GuardRole).setLastGuarded(target);
    }

    state.skillUsed(actor, '守护', target: target);
  }
}

/// 查验动作
class InvestigateAction extends GameAction {
  InvestigateAction({
    required super.actor,
    required Player super.target,
  }) : super(
          type: ActionType.investigate,
          skill: InvestigateSkill(),
        );

  @override
  void _performAction(GameState state) {
    final isWerewolf = target!.role.isWerewolf;
    final result = isWerewolf ? '狼人' : '好人';

    actor.addKnowledge('investigation_${target!.playerId}', {
      'result': result,
      'night': state.dayNumber,
      'actual_role': target!.role.roleId,
    });

    state.skillUsed(actor, '查验', target: target);
  }
}

/// 救治动作
class HealAction extends GameAction {
  HealAction({
    required super.actor,
    required Player super.target,
  }) : super(
          type: ActionType.heal,
          skill: HealSkill(),
        );

  @override
  void _performAction(GameState state) {
    state.cancelTonightKill();

    if (actor.role is WitchRole) {
      (actor.role as WitchRole).useAntidote();
    }

    state.skillUsed(actor, '使用解药', target: target);
  }
}

/// 毒杀动作
class PoisonAction extends GameAction {
  PoisonAction({
    required super.actor,
    required Player super.target,
  }) : super(
          type: ActionType.poison,
          skill: PoisonSkill(),
        );

  @override
  void _performAction(GameState state) {
    state.setTonightPoisoned(target);

    if (actor.role is WitchRole) {
      (actor.role as WitchRole).usePoison();
    }

    state.skillUsed(actor, '使用毒药', target: target);
  }
}

/// 投票动作
class VoteAction extends GameAction {
  VoteAction({
    required super.actor,
    required Player super.target,
  }) : super(
          type: ActionType.vote,
        );

  @override
  void _performAction(GameState state) {
    state.addVote(actor, target!);
    state.playerAction(actor, '投票', target: target);
  }
}

/// 发言动作
class SpeakAction extends GameAction {
  final String message;

  SpeakAction({
    required super.actor,
    required this.message,
  }) : super(
          type: ActionType.speak,
          description: '${actor.name} 发言: $message',
        );

  @override
  void _performAction(GameState state) {
    // Broadcast message to all players
    for (final player in state.players) {
      if (player.isAlive) {
        player.receiveMessage(message, from: actor);
      }
    }

    state.addEvent(GameEvent(
      eventId:
          'speak_${actor.playerId}_${DateTime.now().millisecondsSinceEpoch}',
      type: GameEventType.playerAction,
      description: '${actor.name} 发言: $message',
      initiator: actor,
      data: {
        'actionId': actionId,
        'type': type.name,
        'message': message,
      },
    ));
  }
}

/// 猎人开枪动作
class HunterShootAction extends GameAction {
  HunterShootAction({
    required super.actor,
    required Player super.target,
  }) : super(
          type: ActionType.useSkill,
          skill: HunterShootSkill(),
          description: '${actor.name} 开枪带走了 ${target.name}',
        );

  @override
  void _performAction(GameState state) {
    // Kill the target
    target!.die('被猎人开枪带走', state);

    if (actor.role is HunterRole) {
      (actor.role as HunterRole).shoot();
    }

    state.skillUsed(actor, '开枪', target: target);
  }
}

// Extension methods for GameState to track night actions
extension GameStateNightActions on GameState {
  Player? get tonightVictim => getMetadata('tonight_victim');
  Player? get tonightProtected => getMetadata('tonight_protected');
  Player? get tonightPoisoned => getMetadata('tonight_poisoned');
  bool get killCancelled => getMetadata('kill_cancelled') ?? false;

  void setTonightVictim(Player? victim) {
    setMetadata('tonight_victim', victim?.playerId);
  }

  void setTonightProtected(Player? protected) {
    setMetadata('tonight_protected', protected?.playerId);
  }

  void setTonightPoisoned(Player? poisoned) {
    setMetadata('tonight_poisoned', poisoned?.playerId);
  }

  void cancelTonightKill() {
    setMetadata('kill_cancelled', true);
  }

  void clearNightActions() {
    removeMetadata('tonight_victim');
    removeMetadata('tonight_protected');
    removeMetadata('tonight_poisoned');
    removeMetadata('kill_cancelled');
  }

  T? getMetadata<T>(String key) => metadata[key] as T?;
  void setMetadata<T>(String key, T value) => metadata[key] = value;
  void removeMetadata(String key) => metadata.remove(key);
}

// Extension for GameState voting
extension GameStateVoting on GameState {
  Map<String, String> get votes => getMetadata('votes') ?? {};
  int get totalVotes => votes.length;
  int get requiredVotes => (alivePlayers.length / 2).ceil();

  void addVote(Player voter, Player target) {
    final currentVotes = votes;
    currentVotes[voter.playerId] = target.playerId;
    setMetadata('votes', currentVotes);
  }

  void clearVotes() {
    removeMetadata('votes');
  }

  Map<String, int> getVoteResults() {
    final results = <String, int>{};
    for (final vote in votes.values) {
      results[vote] = (results[vote] ?? 0) + 1;
    }
    return results;
  }

  Player? getVoteTarget() {
    final results = getVoteResults();
    if (results.isEmpty) return null;

    int maxVotes = 0;
    String? targetId;
    for (final entry in results.entries) {
      if (entry.value > maxVotes) {
        maxVotes = entry.value;
        targetId = entry.key;
      }
    }

    if (targetId != null && maxVotes >= requiredVotes) {
      return getPlayerById(targetId);
    }
    return null;
  }
}
