import 'package:werewolf_arena/database/database.dart';

class Migration202510311500 {
  static final createPersonaTableSql = '''
CREATE TABLE player_intelligences(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  base_url TEXT,
  api_key TEXT,
  model_id TEXT NOT NULL
);
''';

  Future<void> migrate() async {
    var laconic = Database.instance.laconic;
    var count = await laconic
        .table('migrations')
        .where('name', 'migration_202510311500')
        .count();
    if (count > 0) return;
    await laconic.statement(createPersonaTableSql);
    await laconic.table('migrations').insert([
      {'name': 'migration_202510311500'},
    ]);
  }
}
