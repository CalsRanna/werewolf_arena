import 'package:werewolf_arena/engine/game_context.dart';
import 'package:werewolf_arena/engine/reasoning/memory/relationship.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';

/// 社会关系网络
///
/// 管理一个玩家视角下所有其他玩家的关系网络
class SocialNetwork {
  /// 网络的主体（谁的视角）
  final String ownerId;

  /// 所有关系映射 (目标玩家ID -> 关系)
  final Map<String, Relationship> relationships;

  /// 最后更新时间
  final DateTime lastUpdated;

  const SocialNetwork({
    required this.ownerId,
    required this.relationships,
    required this.lastUpdated,
  });

  /// 创建初始网络（所有关系都是中立）
  factory SocialNetwork.initial({
    required String ownerId,
    required List<GamePlayer> allPlayers,
  }) {
    final relationships = <String, Relationship>{};

    for (final player in allPlayers) {
      if (player.id != ownerId) {
        relationships[player.id] = Relationship.neutral(
          fromPlayerId: ownerId,
          toPlayerId: player.id,
        );
      }
    }

    return SocialNetwork(
      ownerId: ownerId,
      relationships: relationships,
      lastUpdated: DateTime.now(),
    );
  }

  /// 获取对某个玩家的关系
  Relationship? getRelationship(String playerId) {
    return relationships[playerId];
  }

  /// 更新对某个玩家的关系
  SocialNetwork updateRelationship(
    String playerId,
    Relationship newRelationship,
  ) {
    return SocialNetwork(
      ownerId: ownerId,
      relationships: {...relationships, playerId: newRelationship},
      lastUpdated: DateTime.now(),
    );
  }

  /// 批量更新关系
  SocialNetwork updateMultipleRelationships(
    Map<String, Relationship> newRelationships,
  ) {
    return SocialNetwork(
      ownerId: ownerId,
      relationships: {...relationships, ...newRelationships},
      lastUpdated: DateTime.now(),
    );
  }

  /// 获取所有盟友
  List<String> get allies {
    return relationships.entries
        .where((entry) => entry.value.isAlly)
        .map((entry) => entry.key)
        .toList();
  }

  /// 获取所有敌人
  List<String> get enemies {
    return relationships.entries
        .where((entry) => entry.value.isEnemy)
        .map((entry) => entry.key)
        .toList();
  }

  /// 获取最信任的玩家
  List<String> getMostTrusted({int limit = 3}) {
    final sorted = relationships.entries.toList()
      ..sort((a, b) => b.value.trustLevel.compareTo(a.value.trustLevel));

    return sorted
        .take(limit)
        .where((entry) => entry.value.trustLevel > 0)
        .map((entry) => entry.key)
        .toList();
  }

  /// 获取最怀疑的玩家
  List<String> getMostSuspicious({int limit = 3}) {
    final sorted = relationships.entries.toList()
      ..sort(
        (a, b) => b.value.suspicionLevel.compareTo(a.value.suspicionLevel),
      );

    return sorted
        .take(limit)
        .where((entry) => entry.value.suspicionLevel > 0)
        .map((entry) => entry.key)
        .toList();
  }

  /// 获取所有强关系（重要的盟友或敌人）
  List<String> getStrongRelationships() {
    return relationships.entries
        .where((entry) => entry.value.isStrong)
        .map((entry) => entry.key)
        .toList();
  }

  /// 判断两个玩家是否为盟友（三角关系分析）
  ///
  /// 如果A信任B，B信任C，则C可能也是盟友
  bool areIndirectAllies(String playerId1, String playerId2) {
    final rel1 = getRelationship(playerId1);
    final rel2 = getRelationship(playerId2);

    if (rel1 == null || rel2 == null) return false;

    // 都是盟友
    if (rel1.isAlly && rel2.isAlly) return true;

    return false;
  }

  /// 判断两个玩家是否可能为对立阵营
  ///
  /// 如果A和B互相攻击，或者A信任的人B不信任，则可能对立
  bool areLikelyOpposing(String playerId1, String playerId2) {
    final rel1 = getRelationship(playerId1);
    final rel2 = getRelationship(playerId2);

    if (rel1 == null || rel2 == null) return false;

    // 一个是盟友，一个是敌人
    if (rel1.isAlly && rel2.isEnemy) return true;
    if (rel1.isEnemy && rel2.isAlly) return true;

    return false;
  }

  /// 转换为Prompt文本
  String toPrompt(GameContext state) {
    final buffer = StringBuffer();
    buffer.writeln('## 我的社交关系网络');

    // 按重要性排序（强关系优先）
    final sortedRelationships = relationships.entries.toList()
      ..sort((a, b) => b.value.strength.compareTo(a.value.strength));

    // 只显示重要关系（strength > 0.3）或前5个
    final importantRelationships = sortedRelationships
        .where((entry) => entry.value.strength > 0.3)
        .take(5)
        .toList();

    if (importantRelationships.isEmpty) {
      buffer.writeln('目前没有明确的关系判断');
    } else {
      for (final entry in importantRelationships) {
        final playerId = entry.key;
        final relationship = entry.value;

        // 查找玩家名称
        final player = state.players.firstWhere(
          (p) => p.id == playerId,
          orElse: () => state.players.first,
        );

        buffer.writeln('- ${relationship.toPrompt(player.name)}');
      }
    }

    // 添加盟友和敌人总结
    if (allies.isNotEmpty) {
      final allyNames = allies
          .map((id) {
            final player = state.players.firstWhere(
              (p) => p.id == id,
              orElse: () => state.players.first,
            );
            return player.name;
          })
          .join(', ');
      buffer.writeln('\n**潜在盟友**: $allyNames');
    }

    if (enemies.isNotEmpty) {
      final enemyNames = enemies
          .map((id) {
            final player = state.players.firstWhere(
              (p) => p.id == id,
              orElse: () => state.players.first,
            );
            return player.name;
          })
          .join(', ');
      buffer.writeln('**潜在敌人**: $enemyNames');
    }

    return buffer.toString().trim();
  }

  /// 转换为简洁的Prompt文本（用于非关键步骤）
  String toCompactPrompt(GameContext state) {
    final buffer = StringBuffer();

    final topTrusted = getMostTrusted(limit: 2);
    final topSuspicious = getMostSuspicious(limit: 2);

    if (topTrusted.isNotEmpty) {
      final names = topTrusted
          .map((id) {
            final player = state.players.firstWhere(
              (p) => p.id == id,
              orElse: () => state.players.first,
            );
            return player.name;
          })
          .join(', ');
      buffer.write('信任: $names');
    }

    if (topSuspicious.isNotEmpty) {
      if (topTrusted.isNotEmpty) buffer.write(' | ');
      final names = topSuspicious
          .map((id) {
            final player = state.players.firstWhere(
              (p) => p.id == id,
              orElse: () => state.players.first,
            );
            return player.name;
          })
          .join(', ');
      buffer.write('怀疑: $names');
    }

    return buffer.toString();
  }

  @override
  String toString() {
    return 'SocialNetwork(owner: $ownerId, '
        'relationships: ${relationships.length}, '
        'allies: ${allies.length}, '
        'enemies: ${enemies.length})';
  }
}
