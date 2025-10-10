import 'package:werewolf_arena/core/events/base/game_event.dart';
import 'package:werewolf_arena/core/events/player_events.dart' show DeadEvent;
import 'package:werewolf_arena/core/domain/value_objects/game_event_type.dart';
import 'package:werewolf_arena/core/domain/value_objects/event_visibility.dart';
import 'package:werewolf_arena/core/domain/value_objects/death_cause.dart';
import 'package:werewolf_arena/core/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/core/domain/entities/player.dart';
import 'package:werewolf_arena/core/state/game_state.dart';

/// 狼人击杀事件 - 仅狼人可见
class WerewolfKillEvent extends GameEvent {
  final Player actor;
  final int? dayNumber;
  final GamePhase? phase;

  WerewolfKillEvent({
    required this.actor,
    required Player target,
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
  final Player actor;
  final int? dayNumber;
  final GamePhase? phase;

  GuardProtectEvent({
    required this.actor,
    required Player target,
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
  final Player actor;
  final String investigationResult;
  final int? dayNumber;
  final GamePhase? phase;

  SeerInvestigateEvent({
    required this.actor,
    required Player target,
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
  final Player actor;
  final int? dayNumber;
  final GamePhase? phase;

  WitchHealEvent({
    required this.actor,
    required Player target,
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
  final Player actor;
  final int? dayNumber;
  final GamePhase? phase;

  WitchPoisonEvent({
    required this.actor,
    required Player target,
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
  final Player actor;
  final int? dayNumber;
  final GamePhase? phase;

  HunterShootEvent({
    required this.actor,
    required Player target,
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
