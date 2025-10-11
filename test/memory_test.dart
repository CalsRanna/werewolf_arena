import 'package:test/test.dart';
import 'package:werewolf_arena/core/engine/game_assembler.dart';
import 'package:werewolf_arena/core/engine/game_engine_new.dart';
import 'package:werewolf_arena/core/domain/entities/game_player.dart';
import 'package:werewolf_arena/core/events/player_events.dart';
import 'package:werewolf_arena/core/domain/value_objects/death_cause.dart';
import 'package:werewolf_arena/core/domain/value_objects/vote_type.dart';
import 'package:werewolf_arena/core/domain/value_objects/speech_type.dart';
import 'package:werewolf_arena/core/domain/value_objects/game_event_type.dart';

/// 内存使用和泄漏检测测试
/// 
/// 测试目标：
/// 1. 检查内存泄漏
/// 2. 优化内存使用
/// 3. 验证大规模操作的内存稳定性
void main() {
  group('内存使用测试', () {
    
    test('游戏对象内存占用分析', () async {
      print('=== 游戏对象内存占用分析 ===');
      
      // 创建多个游戏实例并分析内存占用
      final games = <GameEngine>[];
      
      // 基准内存
      print('开始内存分析...');
      
      // 逐步创建游戏并观察内存变化
      for (int i = 0; i < 20; i++) {
        final gameEngine = await GameAssembler.assembleGame(
          scenarioId: '9_players',
        );
        await gameEngine.initializeGame();
        games.add(gameEngine);
        
        // 每5个游戏报告一次内存状态
        if ((i + 1) % 5 == 0) {
          print('已创建 ${i + 1} 个游戏实例');
          print('- 平均玩家数: ${gameEngine.players.length}');
          print('- 事件历史长度: ${gameEngine.currentState?.eventHistory.length ?? 0}');
          print('- 技能效果数: ${gameEngine.currentState?.skillEffects.length ?? 0}');
        }
      }
      
      print('总共创建了 ${games.length} 个游戏实例');
      
      // 验证游戏对象的基本属性
      expect(games.length, equals(20), reason: '应该创建20个游戏实例');
      expect(games.every((g) => g.players.isNotEmpty), isTrue, 
        reason: '所有游戏都应该有玩家');
    });

    test('事件历史内存增长测试', () async {
      print('=== 事件历史内存增长测试 ===');
      
      final gameEngine = await GameAssembler.assembleGame(
        scenarioId: '9_players',
      );
      await gameEngine.initializeGame();
      final gameState = gameEngine.currentState!;
      
      final initialEventCount = gameState.eventHistory.length;
      print('初始事件数量: $initialEventCount');
      
      // 模拟大量事件的添加
      const eventCount = 50000;
      final stopwatch = Stopwatch()..start();
      
      for (int i = 0; i < eventCount; i++) {
        final player = gameState.alivePlayers[i % gameState.alivePlayers.length];
        
        // 添加不同类型的事件
        switch (i % 4) {
          case 0:
            gameState.addEvent(DeadEvent(
              victim: player,
              cause: DeathCause.werewolfKill,
              dayNumber: gameState.dayNumber,
              phase: gameState.currentPhase,
            ));
            break;
          case 1:
            gameState.addEvent(SpeakEvent(
              speaker: player,
              message: '测试发言 $i',
              speechType: SpeechType.normal,
              dayNumber: gameState.dayNumber,
            ));
            break;
          case 2:
            gameState.addEvent(VoteEvent(
              voter: player,
              candidate: gameState.alivePlayers[(i + 1) % gameState.alivePlayers.length],
              voteType: VoteType.normal,
              dayNumber: gameState.dayNumber,
            ));
            break;
          case 3:
            gameState.addEvent(LastWordsEvent(
              speaker: player,
              message: '遗言 $i',
              dayNumber: gameState.dayNumber,
            ));
            break;
        }
        
        // 每10000个事件报告一次状态
        if ((i + 1) % 10000 == 0) {
          print('已添加 ${i + 1} 个事件，总事件数: ${gameState.eventHistory.length}');
        }
      }
      
      stopwatch.stop();
      
      final finalEventCount = gameState.eventHistory.length;
      print('最终事件数量: $finalEventCount');
      print('新增事件数量: ${finalEventCount - initialEventCount}');
      print('添加时间: ${stopwatch.elapsedMilliseconds}ms');
      print('平均添加速度: ${(eventCount / stopwatch.elapsedMilliseconds * 1000).toStringAsFixed(2)} events/sec');
      
      // 验证事件添加的一致性
      expect(finalEventCount, greaterThan(initialEventCount), 
        reason: '应该成功添加大量事件');
      expect(finalEventCount - initialEventCount, equals(eventCount),
        reason: '添加的事件数量应该准确');
    });

    test('事件查询性能在大数据集下的表现', () async {
      print('=== 大数据集事件查询性能测试 ===');
      
      final gameEngine = await GameAssembler.assembleGame(
        scenarioId: '12_players',
      );
      await gameEngine.initializeGame();
      final gameState = gameEngine.currentState!;
      
      // 首先添加大量事件
      const eventCount = 20000;
      print('正在添加 $eventCount 个事件...');
      
      for (int i = 0; i < eventCount; i++) {
        final player = gameState.alivePlayers[i % gameState.alivePlayers.length];
        gameState.addEvent(SpeakEvent(
          speaker: player,
          message: '大数据测试发言 $i',
          speechType: SpeechType.normal,
          dayNumber: gameState.dayNumber + (i ~/ 1000), // 模拟多天
        ));
      }
      
      print('事件添加完成，总事件数: ${gameState.eventHistory.length}');
      
      // 测试不同查询操作的性能
      final stopwatch = Stopwatch();
      
      // 1. 测试获取单个玩家的可见事件
      stopwatch.reset();
      stopwatch.start();
      
      const queryCount = 1000;
      for (int i = 0; i < queryCount; i++) {
        final player = gameState.alivePlayers[i % gameState.alivePlayers.length];
        final visibleEvents = gameState.getEventsForGamePlayer(player);
        // 确保查询确实被执行
        expect(visibleEvents, isNotNull);
      }
      
      stopwatch.stop();
      final queryTime = stopwatch.elapsedMicroseconds;
      print('单玩家事件查询 ($queryCount 次): ${queryTime}μs');
      print('平均查询时间: ${(queryTime / queryCount).toStringAsFixed(2)}μs');
      
      // 2. 测试按类型筛选事件
      stopwatch.reset();
      stopwatch.start();
      
      for (int i = 0; i < 100; i++) {
        final player = gameState.alivePlayers[i % gameState.alivePlayers.length];
        final speechEvents = gameState.getEventsByType(player, GameEventType.playerAction);
        expect(speechEvents, isNotNull);
      }
      
      stopwatch.stop();
      final typeQueryTime = stopwatch.elapsedMicroseconds;
      print('类型筛选查询 (100 次): ${typeQueryTime}μs');
      print('平均类型查询时间: ${(typeQueryTime / 100).toStringAsFixed(2)}μs');
      
      // 性能断言
      expect(queryTime / queryCount, lessThan(5000), 
        reason: '大数据集下单次查询时间应该小于5ms');
      expect(typeQueryTime / 100, lessThan(10000),
        reason: '类型筛选查询时间应该小于10ms');
    });

    test('技能效果存储内存优化测试', () async {
      print('=== 技能效果存储内存优化测试 ===');
      
      final gameEngine = await GameAssembler.assembleGame(
        scenarioId: '9_players',
      );
      await gameEngine.initializeGame();
      final gameState = gameEngine.currentState!;
      
      // 模拟大量技能效果的存储和清理
      const effectCount = 10000;
      
      print('添加 $effectCount 个技能效果...');
      final stopwatch = Stopwatch()..start();
      
      for (int i = 0; i < effectCount; i++) {
        gameState.setSkillEffect('effect_$i', {
          'type': 'test_effect',
          'value': i,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'data': List.generate(10, (j) => 'data_${i}_$j'), // 模拟复杂数据
        });
        
        // 每1000个效果报告一次
        if ((i + 1) % 1000 == 0) {
          print('已添加 ${i + 1} 个技能效果');
        }
      }
      
      stopwatch.stop();
      print('技能效果添加完成，用时: ${stopwatch.elapsedMilliseconds}ms');
      print('当前技能效果数量: ${gameState.skillEffects.length}');
      
      // 测试技能效果查询性能
      stopwatch.reset();
      stopwatch.start();
      
      for (int i = 0; i < 1000; i++) {
        final effectKey = 'effect_${i * 10}';
        final effect = gameState.getSkillEffect(effectKey);
        // 验证查询结果
        if (i * 10 < effectCount) {
          expect(effect, isNotNull, reason: '应该能找到技能效果');
        }
      }
      
      stopwatch.stop();
      print('技能效果查询测试 (1000次): ${stopwatch.elapsedMicroseconds}μs');
      
      // 测试批量清理性能
      stopwatch.reset();
      stopwatch.start();
      
      gameState.clearSkillEffects();
      
      stopwatch.stop();
      print('技能效果清理时间: ${stopwatch.elapsedMicroseconds}μs');
      print('清理后技能效果数量: ${gameState.skillEffects.length}');
      
      // 验证清理效果
      expect(gameState.skillEffects.length, equals(0), 
        reason: '技能效果应该被完全清理');
    });

    test('并发游戏实例内存隔离测试', () async {
      print('=== 并发游戏实例内存隔离测试 ===');
      
      // 创建多个独立的游戏实例
      const gameCount = 10;
      final games = <GameEngine>[];
      
      print('创建 $gameCount 个独立游戏实例...');
      
      for (int i = 0; i < gameCount; i++) {
        final gameEngine = await GameAssembler.assembleGame(
          scenarioId: i % 2 == 0 ? '9_players' : '12_players',
        );
        await gameEngine.initializeGame();
        games.add(gameEngine);
      }
      
      print('游戏实例创建完成');
      
      // 在每个游戏中添加不同的事件和效果
      for (int gameIndex = 0; gameIndex < games.length; gameIndex++) {
        final game = games[gameIndex];
        final gameState = game.currentState!;
        
        // 为每个游戏添加特定的技能效果
        for (int i = 0; i < 100; i++) {
          gameState.setSkillEffect('game_${gameIndex}_effect_$i', {
            'gameId': gameIndex,
            'effectId': i,
            'uniqueData': 'game_${gameIndex}_data_$i',
          });
        }
        
        // 为每个游戏添加特定的事件
        for (int i = 0; i < 50; i++) {
          final player = gameState.alivePlayers[i % gameState.alivePlayers.length];
          gameState.addEvent(SpeakEvent(
            speaker: player,
            message: '游戏${gameIndex}的发言$i',
            speechType: SpeechType.normal,
            dayNumber: gameState.dayNumber,
          ));
        }
      }
      
      print('为所有游戏添加了独立的数据');
      
      // 验证数据隔离性
      for (int gameIndex = 0; gameIndex < games.length; gameIndex++) {
        final game = games[gameIndex];
        final gameState = game.currentState!;
        
        // 验证技能效果隔离
        final gameEffects = gameState.skillEffects.keys
            .where((key) => key.startsWith('game_${gameIndex}_'))
            .toList();
        expect(gameEffects.length, equals(100), 
          reason: '游戏$gameIndex应该有100个独立的技能效果');
        
        // 验证事件隔离
        final gameEvents = gameState.eventHistory
            .whereType<SpeakEvent>()
            .where((event) => event.message.contains('游戏$gameIndex'))
            .toList();
        expect(gameEvents.length, equals(50),
          reason: '游戏$gameIndex应该有50个独立的事件');
        
        // 验证不会有其他游戏的数据污染
        final otherGameEffects = gameState.skillEffects.keys
            .where((key) => key.startsWith('game_') && !key.startsWith('game_${gameIndex}_'))
            .toList();
        expect(otherGameEffects.length, equals(0),
          reason: '游戏$gameIndex不应该包含其他游戏的技能效果');
      }
      
      print('内存隔离验证通过');
      
      // 清理测试：移除一些游戏实例，验证内存清理
      final gamesToRemove = games.sublist(0, 5);
      for (final game in gamesToRemove) {
        // 清理游戏状态
        game.currentState?.clearSkillEffects();
      }
      
      games.removeRange(0, 5);
      print('移除了5个游戏实例');
      
      // 验证剩余游戏的数据完整性
      for (int gameIndex = 5; gameIndex < 10; gameIndex++) {
        final game = games[gameIndex - 5];
        final gameState = game.currentState!;
        
        final remainingEffects = gameState.skillEffects.keys
            .where((key) => key.startsWith('game_${gameIndex}_'))
            .toList();
        expect(remainingEffects.length, equals(100),
          reason: '剩余游戏的数据应该保持完整');
      }
      
      print('并发游戏实例内存隔离测试完成');
    });
  });
}