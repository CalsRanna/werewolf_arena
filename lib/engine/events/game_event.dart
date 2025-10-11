import 'package:werewolf_arena/engine/domain/value_objects/game_event_type.dart';
import 'package:werewolf_arena/engine/domain/value_objects/event_visibility.dart';
import 'package:werewolf_arena/engine/domain/entities/game_role.dart';
import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
import 'package:werewolf_arena/engine/game_state.dart';

/// 游戏事件基类
///
/// 所有游戏中的行为都通过事件来表达,事件驱动整个游戏流程。
/// 每个事件都有可见性规则,确保玩家只能看到他们应该看到的信息。
abstract class GameEvent {
  /// 事件唯一标识
  final String eventId;

  /// 事件发生时间
  final DateTime timestamp;

  /// 事件类型
  final GameEventType type;

  /// 事件发起者
  final GamePlayer? initiator;

  /// 事件目标
  final GamePlayer? target;

  /// 事件可见性
  final EventVisibility visibility;

  /// 可见玩家名单(当visibility为playerSpecific时使用)
  final List<String> visibleToPlayerNames;

  /// 可见角色ID(当visibility为roleSpecific时使用)
  final String? visibleToGameRole;

  /// 事件元数据
  final Map<String, dynamic> metadata;

  GameEvent({
    required this.eventId,
    required this.type,
    this.initiator,
    this.target,
    this.visibility = EventVisibility.public,
    this.visibleToPlayerNames = const [],
    this.visibleToGameRole,
    Map<String, dynamic>? metadata,
  }) : timestamp = DateTime.now(),
       metadata = metadata ?? {};

  /// 执行事件逻辑
  ///
  /// 子类实现此方法来定义事件对游戏状态的影响
  void execute(GameState state);

  /// 检查事件对指定玩家是否可见
  ///
  /// 根据可见性规则判断玩家是否能看到此事件
  bool isVisibleTo(dynamic player) {
    // Extract player properties (support both Player and test objects)
    final playerName = player.name as String;
    final role = player.role as GameRole;
    final isAlive = player.isAlive as bool;

    switch (visibility) {
      case EventVisibility.public:
        return true;

      case EventVisibility.allWerewolves:
        return role.isWerewolf;

      case EventVisibility.roleSpecific:
        return visibleToGameRole != null && role.roleId == visibleToGameRole;

      case EventVisibility.playerSpecific:
        return visibleToPlayerNames.contains(playerName);

      case EventVisibility.dead:
        return !isAlive;
    }
  }

  @override
  String toString() {
    return 'GameEvent($type: $eventId)';
  }

  /// 转换为JSON格式
  Map<String, dynamic> toJson() {
    return {
      'eventId': eventId,
      'timestamp': timestamp.toIso8601String(),
      'type': type.name,
      'initiator': initiator?.name,
      'target': target?.name,
      'visibility': visibility.name,
      'visibleToPlayerNames': visibleToPlayerNames,
      'visibleToGameRole': visibleToGameRole,
      'metadata': metadata,
    };
  }
}
