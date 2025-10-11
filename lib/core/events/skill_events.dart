import 'package:werewolf_arena/core/events/base/game_event.dart';
import 'package:werewolf_arena/core/events/player_events.dart' show DeadEvent;
import 'package:werewolf_arena/core/domain/value_objects/game_event_type.dart';
import 'package:werewolf_arena/core/domain/value_objects/event_visibility.dart';
import 'package:werewolf_arena/core/domain/value_objects/death_cause.dart';
import 'package:werewolf_arena/core/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/core/domain/entities/game_player.dart';
import 'package:werewolf_arena/core/state/game_state.dart';

/// 通用技能执行事件 - 可配置可见性
class SkillExecutionEvent extends GameEvent {
  final String skillId;
  final String skillName;
  final GamePlayer caster;
  @override
  final GamePlayer? target;
  final Map<String, dynamic> skillData;
  final int? dayNumber;
  final GamePhase? phase;

  SkillExecutionEvent({
    required this.skillId,
    required this.skillName,
    required this.caster,
    this.target,
    this.skillData = const {},
    this.dayNumber,
    this.phase,
    super.visibility = EventVisibility.playerSpecific,
    List<String>? visibleToPlayerNames,
  }) : super(
          eventId: 'skill_${skillId}_${caster.name}_${DateTime.now().millisecondsSinceEpoch}',
          type: GameEventType.skillUsed,
          initiator: caster,
          target: target,
          visibleToPlayerNames: visibleToPlayerNames ?? [caster.name],
        );

  @override
  void execute(GameState state) {
    // 技能执行的具体逻辑在技能类中处理，这里只记录事件
    // 可以根据skillData中的信息执行相应的状态变更
    
    // 更新技能使用次数
    state.incrementSkillUsage(skillId);
    
    // 根据技能类型设置相应的技能效果
    if (skillData.isNotEmpty) {
      final effectKey = '${skillId}_${caster.name}';
      state.setSkillEffect(effectKey, skillData);
    }
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'skillId': skillId,
      'skillName': skillName,
      'caster': caster.name,
      'target': target?.name,
      'skillData': skillData,
      'dayNumber': dayNumber,
      'phase': phase?.name,
    };
  }
}

/// 技能结果事件 - 用于公布技能执行的结果
class SkillResultEvent extends GameEvent {
  final String skillId;
  final GamePlayer caster;
  final bool success;
  final String? resultMessage;
  final Map<String, dynamic> resultData;

  SkillResultEvent({
    required this.skillId,
    required this.caster,
    required this.success,
    this.resultMessage,
    this.resultData = const {},
    super.visibility = EventVisibility.public,
  }) : super(
          eventId: 'skill_result_${skillId}_${DateTime.now().millisecondsSinceEpoch}',
          type: GameEventType.skillResult,
          initiator: caster,
        );

  @override
  void execute(GameState state) {
    // 技能结果事件主要用于信息传递，不直接修改游戏状态
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'skillId': skillId,
      'caster': caster.name,
      'success': success,
      'resultMessage': resultMessage,
      'resultData': resultData,
    };
  }
}

/// 狼人击杀事件 - 仅狼人可见
class WerewolfKillEvent extends GameEvent {
  final GamePlayer actor;
  final int? dayNumber;
  final GamePhase? phase;

  WerewolfKillEvent({
    required this.actor,
    required GamePlayer target,
    this.dayNumber,
    this.phase,
  }) : super(
          eventId: 'kill_${actor.name}_${DateTime.now().millisecondsSinceEpoch}',
          type: GameEventType.skillUsed,
          initiator: actor,
          target: target,
          visibility: EventVisibility.allWerewolves,
        );

  @override
  void execute(GameState state) {
    // Mark target for death (will be resolved at end of night)
    // state.setTonightVictim(target!);
  }
}

/// 守卫保护事件 - 仅守卫可见
class GuardProtectEvent extends GameEvent {
  final GamePlayer actor;
  final int? dayNumber;
  final GamePhase? phase;

  GuardProtectEvent({
    required this.actor,
    required GamePlayer target,
    this.dayNumber,
    this.phase,
  }) : super(
          eventId:
              'protect_${actor.name}_${DateTime.now().millisecondsSinceEpoch}',
          type: GameEventType.skillUsed,
          initiator: actor,
          target: target,
          visibility: EventVisibility.playerSpecific,
          visibleToPlayerNames: [actor.name],
        );

  @override
  void execute(GameState state) {
    // state.setTonightProtected(target!);
  }
}

/// 预言家查验事件 - 仅预言家可见
class SeerInvestigateEvent extends GameEvent {
  final GamePlayer actor;
  final String investigationResult;
  final int? dayNumber;
  final GamePhase? phase;

  SeerInvestigateEvent({
    required this.actor,
    required GamePlayer target,
    required this.investigationResult,
    this.dayNumber,
    this.phase,
  }) : super(
          eventId:
              'investigate_${actor.name}_${DateTime.now().millisecondsSinceEpoch}',
          type: GameEventType.skillUsed,
          initiator: actor,
          target: target,
          visibility: EventVisibility.playerSpecific,
          visibleToPlayerNames: [actor.name],
        );

  @override
  void execute(GameState state) {
    // Investigation result is already stored in the event data
    // The seer will access this information through the event system
  }
}

/// 女巫救人事件 - 仅女巫可见
class WitchHealEvent extends GameEvent {
  final GamePlayer actor;
  final int? dayNumber;
  final GamePhase? phase;

  WitchHealEvent({
    required this.actor,
    required GamePlayer target,
    this.dayNumber,
    this.phase,
  }) : super(
          eventId: 'heal_${actor.name}_${DateTime.now().millisecondsSinceEpoch}',
          type: GameEventType.skillUsed,
          initiator: actor,
          target: target,
          visibility: EventVisibility.playerSpecific,
          visibleToPlayerNames: [actor.name],
        );

  @override
  void execute(GameState state) {
    // state.cancelTonightKill();
  }
}

/// 女巫毒杀事件 - 仅女巫可见
class WitchPoisonEvent extends GameEvent {
  final GamePlayer actor;
  final int? dayNumber;
  final GamePhase? phase;

  WitchPoisonEvent({
    required this.actor,
    required GamePlayer target,
    this.dayNumber,
    this.phase,
  }) : super(
          eventId:
              'poison_${actor.name}_${DateTime.now().millisecondsSinceEpoch}',
          type: GameEventType.skillUsed,
          initiator: actor,
          target: target,
          visibility: EventVisibility.playerSpecific,
          visibleToPlayerNames: [actor.name],
        );

  @override
  void execute(GameState state) {
    // state.setTonightPoisoned(target!);
  }
}

/// 猎人开枪事件 - 公开可见
class HunterShootEvent extends GameEvent {
  final GamePlayer actor;
  final int? dayNumber;
  final GamePhase? phase;

  HunterShootEvent({
    required this.actor,
    required GamePlayer target,
    this.dayNumber,
    this.phase,
  }) : super(
          eventId:
              'hunter_shoot_${actor.name}_${DateTime.now().millisecondsSinceEpoch}',
          type: GameEventType.skillUsed,
          initiator: actor,
          target: target,
          visibility: EventVisibility.public,
        );

  @override
  void execute(GameState state) {
    // Create death event for the target
    final deathEvent = DeadEvent(
      victim: target!,
      cause: DeathCause.hunterShot,
      killer: actor,
      dayNumber: dayNumber,
      phase: phase,
    );
    deathEvent.execute(state);
    // state.addEvent(deathEvent);
  }
}
