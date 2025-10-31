import 'package:werewolf_arena/database/database.dart';
import 'package:werewolf_arena/entity/player_intelligence_entity.dart';

class PlayerIntelligenceRepository {
  Future<void> destroyPlayerIntelligence(int id) async {
    var laconic = Database.instance.laconic;
    await laconic.table('player_intelligences').where('id', id).delete();
  }

  Future<PlayerIntelligenceEntity> getPlayerIntelligence(int id) async {
    var laconic = Database.instance.laconic;
    var result = await laconic
        .table('player_intelligences')
        .where('id', id)
        .first();
    return PlayerIntelligenceEntity.fromJson(result.toMap());
  }

  Future<List<PlayerIntelligenceEntity>> getPlayerIntelligences() async {
    var laconic = Database.instance.laconic;
    var results = await laconic.table('player_intelligences').get();
    return results
        .map((result) => PlayerIntelligenceEntity.fromJson(result.toMap()))
        .toList();
  }

  Future<void> storePlayerIntelligence(
    PlayerIntelligenceEntity intelligence,
  ) async {
    var laconic = Database.instance.laconic;
    var json = intelligence.toJson();
    json.remove('id');
    await laconic.table('player_intelligences').insert([json]);
  }

  Future<void> updatePlayerIntelligence(
    PlayerIntelligenceEntity intelligence,
  ) async {
    var laconic = Database.instance.laconic;
    var json = intelligence.toJson();
    json.remove('id');
    await laconic
        .table('player_intelligences')
        .where('id', intelligence.id)
        .update(json);
  }
}
