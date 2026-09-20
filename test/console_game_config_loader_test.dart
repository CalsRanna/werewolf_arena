// 控制台配置加载与日志分级的单元测试。
//
// 覆盖本轮查实的两个缺陷：
//   1) bin/main.dart 注册了 -c/--config，但加载器只认 Directory.current 下的固定文件名，
//      传了路径也不生效。这里直接验证"给了路径就读那个文件"。
//   2) ConsoleGameObserver 默认把 LogEvent 整体丢掉，导致引擎内部失败（如
//      AIPlayer.cast 捕获异常后静默返回空发言）完全不可见。这里验证分级判定。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:werewolf_arena/console/console_game_config_loader.dart';
import 'package:werewolf_arena/engine/event/log_event.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('ww_cfg_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  String writeConfig(String name, String body) {
    final file = File('${tempDir.path}/$name');
    file.writeAsStringSync(body);
    return file.path;
  }

  const baseYaml = '''
default_llm:
  api_key: sk-test-not-a-real-key
  base_url: "https://example.invalid/api/v1"
  max_retries: 5

fast_model_id: test/fast-model

player_models:
  - test/player-model
''';

  group('loadGameConfig(configPath:)', () {
    test('显式路径生效：读的是给定文件，而非当前目录下的固定文件名', () async {
      final path = writeConfig('explicit.yaml', baseYaml);

      final config = await ConsoleGameConfigLoader().loadGameConfig(
        configPath: path,
      );

      expect(config.fastModelId, 'test/fast-model');
      expect(config.maxRetries, 5);
      expect(config.playerIntelligences, hasLength(12));
      expect(config.playerIntelligences.first.modelId, 'test/player-model');
      // 未声明 systemone 段时判定层必须为 null（行为等价改造前）
      expect(config.jevSettings, isNull);
    });

    test('声明的 systemone 段被解析为 Jev 设置', () async {
      final path = writeConfig(
        'jev.yaml',
        '$baseYaml\nsystemone:\n'
            '  base_url: "https://example.invalid/api"\n'
            '  model: "typesafe/jev-1.13"\n',
      );

      final config = await ConsoleGameConfigLoader().loadGameConfig(
        configPath: path,
      );

      expect(config.jevSettings, isNotNull);
      expect(config.jevSettings!.enabled, isTrue);
      expect(config.jevSettings!.model, 'typesafe/jev-1.13');
      expect(config.jevSettings!.baseUrl, 'https://example.invalid/api');
    });

    test('显式路径不存在时不猜、不造文件，退回默认配置', () async {
      final missing = '${tempDir.path}/nope.yaml';

      final config = await ConsoleGameConfigLoader().loadGameConfig(
        configPath: missing,
      );

      expect(config.playerIntelligences, isNotEmpty);
      expect(File(missing).existsSync(), isFalse);
    });
  });

  group('LogEvent 分级', () {
    test('warning 及以上视为需要默认可见', () {
      expect(LogEvent.debug('d').isProblem, isFalse);
      expect(LogEvent.info('i').isProblem, isFalse);
      expect(LogEvent('plain').isProblem, isFalse);
      expect(LogEvent.warning('w').isProblem, isTrue);
      expect(LogEvent.error('e').isProblem, isTrue);
    });

    test('叙述里带级别名', () {
      expect(LogEvent.error('boom').toNarrative(), contains('[error] boom'));
    });
  });
}
