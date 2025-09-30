import 'package:test/test.dart';
import 'package:werewolf_arena/game/game_state.dart';
import 'package:werewolf_arena/game/game_event.dart';
import 'package:werewolf_arena/player/role.dart';

void main() {
  group('Game Event System Tests', () {
    test('DeadEvent should be public and mark player as dead', () {
      final player = _createTestPlayer('player1', VillagerRole());
      expect(player.isAlive, isTrue);

      final event = DeadEvent(
        player: player,
        cause: '被狼人击杀',
        dayNumber: 1,
        phase: 'night',
      );

      expect(event.visibility, equals(EventVisibility.public));
      expect(event.type, equals(GameEventType.playerDeath));
      expect(event.description, contains('死亡'));

      // All players should see this event
      final werewolf = _createTestPlayer('werewolf1', WerewolfRole());
      final seer = _createTestPlayer('seer1', SeerRole());
      expect(event.isVisibleTo(player), isTrue);
      expect(event.isVisibleTo(werewolf), isTrue);
      expect(event.isVisibleTo(seer), isTrue);
    });

    test('WerewolfKillEvent should only be visible to werewolves', () {
      final werewolf = _createTestPlayer('werewolf1', WerewolfRole());
      final target = _createTestPlayer('target1', VillagerRole());

      final event = WerewolfKillEvent(
        actor: werewolf,
        target: target,
        dayNumber: 1,
        phase: 'night',
      );

      expect(event.visibility, equals(EventVisibility.allWerewolves));
      expect(event.type, equals(GameEventType.skillUsed));

      final seer = _createTestPlayer('seer1', SeerRole());
      final anotherWerewolf = _createTestPlayer('werewolf2', WerewolfRole());

      expect(event.isVisibleTo(werewolf), isTrue);
      expect(event.isVisibleTo(anotherWerewolf), isTrue);
      expect(event.isVisibleTo(seer), isFalse);
      expect(event.isVisibleTo(target), isFalse);
    });

    test('GuardProtectEvent should only be visible to the guard', () {
      final guard = _createTestPlayer('guard1', GuardRole());
      final target = _createTestPlayer('target1', VillagerRole());

      final event = GuardProtectEvent(
        actor: guard,
        target: target,
        dayNumber: 1,
        phase: 'night',
      );

      expect(event.visibility, equals(EventVisibility.playerSpecific));
      expect(event.visibleToPlayerIds, contains(guard.playerId));
      expect(event.type, equals(GameEventType.skillUsed));

      final werewolf = _createTestPlayer('werewolf1', WerewolfRole());
      final seer = _createTestPlayer('seer1', SeerRole());

      expect(event.isVisibleTo(guard), isTrue);
      expect(event.isVisibleTo(target), isFalse);
      expect(event.isVisibleTo(werewolf), isFalse);
      expect(event.isVisibleTo(seer), isFalse);
    });

    test('SeerInvestigateEvent should only be visible to the seer', () {
      final seer = _createTestPlayer('seer1', SeerRole());
      final target = _createTestPlayer('werewolf1', WerewolfRole());

      final event = SeerInvestigateEvent(
        actor: seer,
        target: target,
        investigationResult: 'Werewolf',
        dayNumber: 1,
        phase: 'night',
      );

      expect(event.visibility, equals(EventVisibility.playerSpecific));
      expect(event.visibleToPlayerIds, contains(seer.playerId));
      expect(event.type, equals(GameEventType.skillUsed));
      expect(event.investigationResult, equals('Werewolf'));

      final guard = _createTestPlayer('guard1', GuardRole());
      final villager = _createTestPlayer('villager1', VillagerRole());

      expect(event.isVisibleTo(seer), isTrue);
      expect(event.isVisibleTo(target), isFalse);
      expect(event.isVisibleTo(guard), isFalse);
      expect(event.isVisibleTo(villager), isFalse);
    });

    test('WitchHealEvent should only be visible to the witch', () {
      final witch = _createTestPlayer('witch1', WitchRole());
      final target = _createTestPlayer('target1', VillagerRole());

      final event = WitchHealEvent(
        actor: witch,
        target: target,
        dayNumber: 1,
        phase: 'night',
      );

      expect(event.visibility, equals(EventVisibility.playerSpecific));
      expect(event.visibleToPlayerIds, contains(witch.playerId));
      expect(event.type, equals(GameEventType.skillUsed));

      final seer = _createTestPlayer('seer1', SeerRole());
      expect(event.isVisibleTo(witch), isTrue);
      expect(event.isVisibleTo(target), isFalse);
      expect(event.isVisibleTo(seer), isFalse);
    });

    test('WitchPoisonEvent should only be visible to the witch', () {
      final witch = _createTestPlayer('witch1', WitchRole());
      final target = _createTestPlayer('target1', VillagerRole());

      final event = WitchPoisonEvent(
        actor: witch,
        target: target,
        dayNumber: 1,
        phase: 'night',
      );

      expect(event.visibility, equals(EventVisibility.playerSpecific));
      expect(event.visibleToPlayerIds, contains(witch.playerId));
      expect(event.type, equals(GameEventType.skillUsed));

      final seer = _createTestPlayer('seer1', SeerRole());
      expect(event.isVisibleTo(witch), isTrue);
      expect(event.isVisibleTo(target), isFalse);
      expect(event.isVisibleTo(seer), isFalse);
    });

    test('VoteEvent should be public', () {
      final voter = _createTestPlayer('player1', VillagerRole());
      final target = _createTestPlayer('player2', WerewolfRole());

      final event = VoteEvent(
        actor: voter,
        target: target,
        dayNumber: 1,
        phase: 'voting',
      );

      expect(event.visibility, equals(EventVisibility.public));
      expect(event.type, equals(GameEventType.voteCast));

      final werewolf = _createTestPlayer('werewolf1', WerewolfRole());
      final seer = _createTestPlayer('seer1', SeerRole());

      expect(event.isVisibleTo(voter), isTrue);
      expect(event.isVisibleTo(target), isTrue);
      expect(event.isVisibleTo(werewolf), isTrue);
      expect(event.isVisibleTo(seer), isTrue);
    });

    test('SpeakEvent should be public', () {
      final speaker = _createTestPlayer('player1', VillagerRole());

      final event = SpeakEvent(
        actor: speaker,
        message: 'I think player 2 is suspicious',
        dayNumber: 1,
        phase: 'day',
      );

      expect(event.visibility, equals(EventVisibility.public));
      expect(event.type, equals(GameEventType.playerAction));
      expect(event.message, equals('I think player 2 is suspicious'));

      final werewolf = _createTestPlayer('werewolf1', WerewolfRole());
      final seer = _createTestPlayer('seer1', SeerRole());

      expect(event.isVisibleTo(speaker), isTrue);
      expect(event.isVisibleTo(werewolf), isTrue);
      expect(event.isVisibleTo(seer), isTrue);
    });

    test('HunterShootEvent should be public', () {
      final hunter = _createTestPlayer('hunter1', HunterRole());
      final target = _createTestPlayer('target1', WerewolfRole());

      final event = HunterShootEvent(
        actor: hunter,
        target: target,
        dayNumber: 1,
        phase: 'day',
      );

      expect(event.visibility, equals(EventVisibility.public));
      expect(event.type, equals(GameEventType.skillUsed));

      final werewolf = _createTestPlayer('werewolf1', WerewolfRole());
      final seer = _createTestPlayer('seer1', SeerRole());

      expect(event.isVisibleTo(hunter), isTrue);
      expect(event.isVisibleTo(target), isTrue);
      expect(event.isVisibleTo(werewolf), isTrue);
      expect(event.isVisibleTo(seer), isTrue);
    });

    test('PhaseChangeEvent should be public', () {
      final event = PhaseChangeEvent(
        oldPhase: GamePhase.night,
        newPhase: GamePhase.day,
        dayNumber: 1,
      );

      expect(event.visibility, equals(EventVisibility.public));
      expect(event.type, equals(GameEventType.phaseChange));
      expect(event.oldPhase, equals(GamePhase.night));
      expect(event.newPhase, equals(GamePhase.day));

      final werewolf = _createTestPlayer('werewolf1', WerewolfRole());
      final seer = _createTestPlayer('seer1', SeerRole());
      final villager = _createTestPlayer('villager1', VillagerRole());

      expect(event.isVisibleTo(werewolf), isTrue);
      expect(event.isVisibleTo(seer), isTrue);
      expect(event.isVisibleTo(villager), isTrue);
    });

    test('GameStartEvent should be public', () {
      final event = GameStartEvent(
        playerCount: 8,
        roleDistribution: {
          'werewolf': 2,
          'villager': 4,
          'seer': 1,
          'guard': 1,
        },
      );

      expect(event.visibility, equals(EventVisibility.public));
      expect(event.type, equals(GameEventType.gameStart));

      final werewolf = _createTestPlayer('werewolf1', WerewolfRole());
      final seer = _createTestPlayer('seer1', SeerRole());

      expect(event.isVisibleTo(werewolf), isTrue);
      expect(event.isVisibleTo(seer), isTrue);
    });

    test('GameEndEvent should be public', () {
      final startTime = DateTime.now().subtract(Duration(minutes: 30));
      final event = GameEndEvent(
        winner: 'Good',
        totalDays: 3,
        finalPlayerCount: 4,
        startTime: startTime,
      );

      expect(event.visibility, equals(EventVisibility.public));
      expect(event.type, equals(GameEventType.gameEnd));
      expect(event.winner, equals('Good'));
      expect(event.totalDays, equals(3));

      final werewolf = _createTestPlayer('werewolf1', WerewolfRole());
      final seer = _createTestPlayer('seer1', SeerRole());

      expect(event.isVisibleTo(werewolf), isTrue);
      expect(event.isVisibleTo(seer), isTrue);
    });
  });
}

// Helper function to create a test player
_TestPlayer _createTestPlayer(String playerId, Role role) {
  return _TestPlayer(playerId: playerId, name: 'Player_$playerId', role: role);
}

// Minimal test player implementation
class _TestPlayer {
  final String playerId;
  final String name;
  final Role role;
  bool isAlive = true;

  _TestPlayer({
    required this.playerId,
    required this.name,
    required this.role,
  });
}