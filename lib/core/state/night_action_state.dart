import 'package:werewolf_arena/core/domain/entities/player.dart';

class NightActionState {
  Player? tonightVictim;
  Player? tonightProtected;
  Player? tonightPoisoned;
  bool killCancelled;

  NightActionState({
    this.tonightVictim,
    this.tonightProtected,
    this.tonightPoisoned,
    this.killCancelled = false,
  });

  void setTonightVictim(Player? victim) {
    tonightVictim = victim;
  }

  void setTonightProtected(Player? protected) {
    tonightProtected = protected;
  }

  void setTonightPoisoned(Player? poisoned) {
    tonightPoisoned = poisoned;
  }

  void cancelTonightKill() {
    killCancelled = true;
  }

  void clearNightActions() {
    tonightVictim = null;
    tonightProtected = null;
    tonightPoisoned = null;
    killCancelled = false;
  }

  Map<String, dynamic> toJson() {
    return {
      'tonightVictim': tonightVictim?.name,
      'tonightProtected': tonightProtected?.name,
      'tonightPoisoned': tonightPoisoned?.name,
      'killCancelled': killCancelled,
    };
  }

  factory NightActionState.fromJson(Map<String, dynamic> json, List<Player> players) {
    return NightActionState(
      tonightVictim: _playerFromName(players, json['tonightVictim']),
      tonightProtected: _playerFromName(players, json['tonightProtected']),
      tonightPoisoned: _playerFromName(players, json['tonightPoisoned']),
      killCancelled: json['killCancelled'] ?? false,
    );
  }

  static Player? _playerFromName(List<Player> players, String? name) {
    if (name == null) return null;
    try {
      return players.firstWhere((p) => p.name == name);
    } catch (e) {
      return null;
    }
  }
}
