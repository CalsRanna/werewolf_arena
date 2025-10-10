import 'package:werewolf_arena/core/domain/entities/player.dart';

/// 夜晚行动状态管理类
///
/// 负责管理游戏夜晚阶段的各种行动状态，包括狼人击杀、守卫保护、女巫用药等。
/// 这个类封装了夜晚行动的临时状态，使用组合模式与 GameState 配合使用。
///
/// 主要功能：
/// - 追踪当晚的击杀目标
/// - 追踪当晚的保护目标
/// - 追踪当晚的毒杀目标
/// - 管理击杀是否被取消的状态
/// - 提供状态清理和序列化功能
///
/// 使用示例：
/// ```dart
/// final nightState = NightActionState();
/// nightState.setTonightVictim(werewolfTarget);
/// nightState.setTonightProtected(guardTarget);
///
/// // 夜晚结算后清理状态
/// nightState.clearNightActions();
/// ```
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
