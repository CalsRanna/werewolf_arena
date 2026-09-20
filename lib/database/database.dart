import 'dart:io';

import 'package:laconic/laconic.dart';
import 'package:laconic_sqlite/laconic_sqlite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:werewolf_arena/database/migration/migration_202510311500.dart';
import 'package:werewolf_arena/util/logger_util.dart';

class Database {
  static final Database instance = Database._internal();

  late Laconic laconic;
  final _migrationCreateSql = '''
CREATE TABLE migrations(
  name TEXT NOT NULL
);
''';
  final _checkMigrationExistSql = '''
SELECT name FROM sqlite_master WHERE type='table' AND name='migrations';
''';

  Database._internal();

  Future<void> ensureInitialized() async {
    var directory = await getApplicationSupportDirectory();
    var path = join(directory.path, 'source_parser.db');
    var file = File(path);
    LoggerUtil.instance.i('sqlite path: $path');
    var exists = await file.exists();
    if (!exists) {
      await file.create(recursive: true);
    }
    // laconic 5.x：sqlite 驱动拆到 laconic_sqlite，构造方式改为
    // Laconic(驱动)；查询对象的字段名也从 rawSql 改为 sql。
    laconic = Laconic(
      SqliteDriver(SqliteConfig(path)),
      listen: (query) {
        LoggerUtil.instance.d(query.sql);
      },
    );
    await _migrate();
  }

  Future<void> _migrate() async {
    var tables = await laconic.select(_checkMigrationExistSql);
    if (tables.isEmpty) {
      await laconic.statement(_migrationCreateSql);
    }
    await Migration202510311500().migrate();
  }
}
