import 'package:test/test.dart';
import 'package:werewolf_arena/game/game_state.dart';
import 'package:werewolf_arena/player/role.dart';

void main() {
  group('GameEvent Visibility Tests', () {
    test('Public events should be visible to all players', () {
      final publicEvent = GameEvent(
        eventId: 'test_public',
        type: GameEventType.phaseChange,
        description: 'Phase changed to Night',
        visibility: EventVisibility.public,
      );

      // Create test players with mocked roles
      final werewolf = _createTestPlayer('werewolf1', WerewolfRole());
      final seer = _createTestPlayer('seer1', SeerRole());
      final villager = _createTestPlayer('villager1', VillagerRole());
      final guard = _createTestPlayer('guard1', GuardRole());

      expect(publicEvent.isVisibleTo(werewolf), isTrue);
      expect(publicEvent.isVisibleTo(seer), isTrue);
      expect(publicEvent.isVisibleTo(villager), isTrue);
      expect(publicEvent.isVisibleTo(guard), isTrue);
    });

    test('AllWerewolves events should only be visible to werewolves', () {
      final werewolfEvent = GameEvent(
        eventId: 'test_werewolf',
        type: GameEventType.skillUsed,
        description: 'Werewolf kill action',
        visibility: EventVisibility.allWerewolves,
      );

      final werewolf = _createTestPlayer('werewolf1', WerewolfRole());
      final seer = _createTestPlayer('seer1', SeerRole());
      final villager = _createTestPlayer('villager1', VillagerRole());
      final guard = _createTestPlayer('guard1', GuardRole());

      expect(werewolfEvent.isVisibleTo(werewolf), isTrue);
      expect(werewolfEvent.isVisibleTo(seer), isFalse);
      expect(werewolfEvent.isVisibleTo(villager), isFalse);
      expect(werewolfEvent.isVisibleTo(guard), isFalse);
    });

    test('PlayerSpecific events should only be visible to specified players',
        () {
      final seer = _createTestPlayer('seer1', SeerRole());
      final werewolf = _createTestPlayer('werewolf1', WerewolfRole());
      final villager = _createTestPlayer('villager1', VillagerRole());
      final guard = _createTestPlayer('guard1', GuardRole());

      final seerEvent = GameEvent(
        eventId: 'test_seer',
        type: GameEventType.skillUsed,
        description: 'Seer investigation result',
        visibility: EventVisibility.playerSpecific,
        visibleToPlayerIds: [seer.playerId],
      );

      expect(seerEvent.isVisibleTo(seer), isTrue);
      expect(seerEvent.isVisibleTo(werewolf), isFalse);
      expect(seerEvent.isVisibleTo(villager), isFalse);
      expect(seerEvent.isVisibleTo(guard), isFalse);
    });

    test('RoleSpecific events should only be visible to specific role', () {
      final guardEvent = GameEvent(
        eventId: 'test_guard',
        type: GameEventType.skillUsed,
        description: 'Guard protection',
        visibility: EventVisibility.roleSpecific,
        visibleToRole: 'guard',
      );

      final guard = _createTestPlayer('guard1', GuardRole());
      final seer = _createTestPlayer('seer1', SeerRole());
      final werewolf = _createTestPlayer('werewolf1', WerewolfRole());
      final villager = _createTestPlayer('villager1', VillagerRole());

      expect(guardEvent.isVisibleTo(guard), isTrue);
      expect(guardEvent.isVisibleTo(seer), isFalse);
      expect(guardEvent.isVisibleTo(werewolf), isFalse);
      expect(guardEvent.isVisibleTo(villager), isFalse);
    });

    test('Dead visibility events should only be visible to dead players', () {
      final villager = _createTestPlayer('villager1', VillagerRole());
      final werewolf = _createTestPlayer('werewolf1', WerewolfRole());
      final seer = _createTestPlayer('seer1', SeerRole());
      final guard = _createTestPlayer('guard1', GuardRole());

      villager.isAlive = false; // Kill the villager

      final deadEvent = GameEvent(
        eventId: 'test_dead',
        type: GameEventType.playerAction,
        description: 'Dead chat event',
        visibility: EventVisibility.dead,
      );

      expect(deadEvent.isVisibleTo(villager), isTrue);
      expect(deadEvent.isVisibleTo(werewolf), isFalse);
      expect(deadEvent.isVisibleTo(seer), isFalse);
      expect(deadEvent.isVisibleTo(guard), isFalse);
    });

    test('EventVisibility enum should be serializable to JSON', () {
      final event = GameEvent(
        eventId: 'test_json',
        type: GameEventType.skillUsed,
        description: 'Test event',
        visibility: EventVisibility.playerSpecific,
        visibleToPlayerIds: ['player1', 'player2'],
        visibleToRole: 'seer',
      );

      final json = event.toJson();

      expect(json['visibility'], equals('playerSpecific'));
      expect(json['visibleToPlayerIds'], equals(['player1', 'player2']));
      expect(json['visibleToRole'], equals('seer'));
    });
  });
}

// Helper function to create a test player
_TestPlayer _createTestPlayer(String playerId, Role role) {
  return _TestPlayer(playerId: playerId, role: role);
}

// Minimal test player implementation
class _TestPlayer {
  final String playerId;
  final Role role;
  bool isAlive = true;

  _TestPlayer({
    required this.playerId,
    required this.role,
  });
}