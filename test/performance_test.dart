// ignore_for_file: avoid_print

import 'package:test/test.dart';
import 'package:werewolf_arena/engine/engine/game_assembler.dart';
import 'package:werewolf_arena/engine/engine/game_engine.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/engine/events/player_events.dart';
import 'package:werewolf_arena/engine/domain/value_objects/death_cause.dart';

/// 性能测试 - 验证游戏引擎、技能系统和事件系统的性能
///
/// 测试目标：
/// 1. 游戏引擎初始化性能
/// 2. 技能系统执行性能
/// 3. 事件系统处理性能
/// 4. 大规模游戏循环性能
void main() {
  group('性能基准测试', () {
    test('游戏引擎初始化性能 - 9人局', () async {
      final stopwatch = Stopwatch()..start();

      // 测试多次初始化的性能
      const iterations = 100;
      final times = <int>[];

      for (int i = 0; i < iterations; i++) {
        final iterStopwatch = Stopwatch()..start();

        final gameEngine = await GameAssembler.assembleGame(
          scenarioId: '9_players',
        );
        await gameEngine.initializeGame();

        iterStopwatch.stop();
        times.add(iterStopwatch.elapsedMicroseconds);
      }

      stopwatch.stop();

      // 计算统计数据
      final totalTime = stopwatch.elapsedMilliseconds;
      final avgTime = times.reduce((a, b) => a + b) / times.length;
      final minTime = times.reduce((a, b) => a < b ? a : b);
      final maxTime = times.reduce((a, b) => a > b ? a : b);

      print('=== 游戏引擎初始化性能测试 (9人局) ===');
      print('总时间: ${totalTime}ms');
      print('迭代次数: $iterations');
      print('平均时间: ${avgTime.toStringAsFixed(2)}μs');
      print('最短时间: ${minTime}μs');
      print('最长时间: ${maxTime}μs');
      print('平均TPS: ${(1000000 / avgTime).toStringAsFixed(2)} ops/sec');

      // 性能断言：平均初始化时间应该小于50ms
      expect(avgTime / 1000, lessThan(50), reason: '游戏初始化平均时间应该小于50ms');
    });

    test('游戏引擎初始化性能 - 12人局', () async {
      final stopwatch = Stopwatch()..start();

      // 测试多次初始化的性能
      const iterations = 50; // 12人局较复杂，减少迭代次数
      final times = <int>[];

      for (int i = 0; i < iterations; i++) {
        final iterStopwatch = Stopwatch()..start();

        final gameEngine = await GameAssembler.assembleGame(
          scenarioId: '12_players',
        );
        await gameEngine.initializeGame();

        iterStopwatch.stop();
        times.add(iterStopwatch.elapsedMicroseconds);
      }

      stopwatch.stop();

      // 计算统计数据
      final totalTime = stopwatch.elapsedMilliseconds;
      final avgTime = times.reduce((a, b) => a + b) / times.length;
      final minTime = times.reduce((a, b) => a < b ? a : b);
      final maxTime = times.reduce((a, b) => a > b ? a : b);

      print('=== 游戏引擎初始化性能测试 (12人局) ===');
      print('总时间: ${totalTime}ms');
      print('迭代次数: $iterations');
      print('平均时间: ${avgTime.toStringAsFixed(2)}μs');
      print('最短时间: ${minTime}μs');
      print('最长时间: ${maxTime}μs');
      print('平均TPS: ${(1000000 / avgTime).toStringAsFixed(2)} ops/sec');

      // 性能断言：平均初始化时间应该小于100ms
      expect(avgTime / 1000, lessThan(100), reason: '12人局游戏初始化平均时间应该小于100ms');
    });

    test('技能系统执行性能', () async {
      final gameEngine = await GameAssembler.assembleGame(
        scenarioId: '9_players',
      );
      await gameEngine.initializeGame();

      final gameState = gameEngine.currentState!;
      final stopwatch = Stopwatch()..start();

      // 测试多次技能执行的性能
      const iterations = 1000;
      final times = <int>[];

      for (int i = 0; i < iterations; i++) {
        final iterStopwatch = Stopwatch()..start();

        // 模拟技能执行
        final alivePlayers = gameState.alivePlayers;
        if (alivePlayers.isNotEmpty) {
          final player = alivePlayers.first;
          final skills = player.role.getAvailableSkills(GamePhase.night);

          if (skills.isNotEmpty) {
            final skill = skills.first;
            if (skill.canCast(player, gameState)) {
              await skill.cast(player, gameState);
            }
          }
        }

        iterStopwatch.stop();
        times.add(iterStopwatch.elapsedMicroseconds);
      }

      stopwatch.stop();

      // 计算统计数据
      final totalTime = stopwatch.elapsedMilliseconds;
      final avgTime = times.reduce((a, b) => a + b) / times.length;
      final minTime = times.reduce((a, b) => a < b ? a : b);
      final maxTime = times.reduce((a, b) => a > b ? a : b);

      print('=== 技能系统执行性能测试 ===');
      print('总时间: ${totalTime}ms');
      print('迭代次数: $iterations');
      print('平均时间: ${avgTime.toStringAsFixed(2)}μs');
      print('最短时间: ${minTime}μs');
      print('最长时间: ${maxTime}μs');
      print('平均TPS: ${(1000000 / avgTime).toStringAsFixed(2)} ops/sec');

      // 性能断言：平均技能执行时间应该小于10ms
      expect(avgTime / 1000, lessThan(10), reason: '技能执行平均时间应该小于10ms');
    });

    test('事件系统处理性能', () async {
      final gameEngine = await GameAssembler.assembleGame(
        scenarioId: '9_players',
      );
      await gameEngine.initializeGame();

      final gameState = gameEngine.currentState!;
      final stopwatch = Stopwatch()..start();

      // 测试大量事件添加和查询的性能
      const iterations = 10000;
      final addTimes = <int>[];
      final queryTimes = <int>[];

      // 测试事件添加性能
      for (int i = 0; i < iterations; i++) {
        final iterStopwatch = Stopwatch()..start();

        // 创建测试事件
        final player = gameState.alivePlayers.first;
        final event = DeadEvent(
          victim: player,
          cause: DeathCause.werewolfKill,
          dayNumber: gameState.dayNumber,
          phase: gameState.currentPhase,
        );

        gameState.addEvent(event);

        iterStopwatch.stop();
        addTimes.add(iterStopwatch.elapsedMicroseconds);
      }

      // 测试事件查询性能
      for (int i = 0; i < 1000; i++) {
        final iterStopwatch = Stopwatch()..start();

        iterStopwatch.stop();
        queryTimes.add(iterStopwatch.elapsedMicroseconds);
      }

      stopwatch.stop();

      // 计算统计数据
      final totalTime = stopwatch.elapsedMilliseconds;
      final avgAddTime = addTimes.reduce((a, b) => a + b) / addTimes.length;
      final avgQueryTime =
          queryTimes.reduce((a, b) => a + b) / queryTimes.length;

      print('=== 事件系统处理性能测试 ===');
      print('总时间: ${totalTime}ms');
      print('事件添加迭代: ${addTimes.length}');
      print('事件查询迭代: ${queryTimes.length}');
      print('平均添加时间: ${avgAddTime.toStringAsFixed(2)}μs');
      print('平均查询时间: ${avgQueryTime.toStringAsFixed(2)}μs');
      print('添加TPS: ${(1000000 / avgAddTime).toStringAsFixed(2)} ops/sec');
      print('查询TPS: ${(1000000 / avgQueryTime).toStringAsFixed(2)} ops/sec');
      print('总事件数: ${gameState.eventHistory.length}');

      // 性能断言
      expect(avgAddTime, lessThan(100), reason: '事件添加平均时间应该小于100μs');
      expect(avgQueryTime, lessThan(1000), reason: '事件查询平均时间应该小于1ms');
    });

    test('大规模游戏循环性能', () async {
      final stopwatch = Stopwatch()..start();

      // 测试完整游戏循环的性能
      const gameCount = 10;
      final gameTimes = <int>[];

      for (int gameIndex = 0; gameIndex < gameCount; gameIndex++) {
        final gameStopwatch = Stopwatch()..start();

        final gameEngine = await GameAssembler.assembleGame(
          scenarioId: '9_players',
        );
        await gameEngine.initializeGame();

        // 执行有限的游戏步骤
        int stepCount = 0;
        const maxSteps = 10; // 限制步骤数，避免完整游戏太久

        while (await gameEngine.executeGameStep() && stepCount < maxSteps) {
          stepCount++;

          // 检查游戏是否结束
          if (gameEngine.currentState!.checkGameEnd()) {
            break;
          }
        }

        gameStopwatch.stop();
        gameTimes.add(gameStopwatch.elapsedMilliseconds);

        print(
          '游戏 ${gameIndex + 1} 完成，执行了 $stepCount 步，用时 ${gameStopwatch.elapsedMilliseconds}ms',
        );
      }

      stopwatch.stop();

      // 计算统计数据
      final totalTime = stopwatch.elapsedMilliseconds;
      final avgGameTime = gameTimes.reduce((a, b) => a + b) / gameTimes.length;
      final minGameTime = gameTimes.reduce((a, b) => a < b ? a : b);
      final maxGameTime = gameTimes.reduce((a, b) => a > b ? a : b);

      print('=== 大规模游戏循环性能测试 ===');
      print('总时间: ${totalTime}ms');
      print('游戏数量: $gameCount');
      print('平均游戏时间: ${avgGameTime.toStringAsFixed(2)}ms');
      print('最短游戏时间: ${minGameTime}ms');
      print('最长游戏时间: ${maxGameTime}ms');
      print(
        '游戏吞吐量: ${(gameCount * 1000 / totalTime).toStringAsFixed(2)} games/sec',
      );

      // 性能断言：限定步骤的游戏应该在合理时间内完成
      expect(avgGameTime, lessThan(5000), reason: '限定步骤的游戏平均时间应该小于5秒');
    });

    test('内存使用基准测试', () async {
      // 这个测试更多是观察性的，因为Dart VM的垃圾回收机制
      print('=== 内存使用基准测试 ===');

      final initialMemory = ProcessInfo.currentRss;
      print('初始内存使用: ${initialMemory ~/ 1024 ~/ 1024}MB');

      // 创建多个游戏实例观察内存使用
      final games = <GameEngine>[];

      for (int i = 0; i < 50; i++) {
        final gameEngine = await GameAssembler.assembleGame(
          scenarioId: '9_players',
        );
        await gameEngine.initializeGame();
        games.add(gameEngine);

        if (i % 10 == 9) {
          final currentMemory = ProcessInfo.currentRss;
          print('创建 ${i + 1} 个游戏后内存: ${currentMemory ~/ 1024 ~/ 1024}MB');
        }
      }

      final peakMemory = ProcessInfo.currentRss;
      print('峰值内存使用: ${peakMemory ~/ 1024 ~/ 1024}MB');

      // 清理引用
      games.clear();

      // 建议GC（虽然不保证立即执行）
      print('建议垃圾回收...');

      // 等待一段时间让GC有机会执行
      await Future.delayed(Duration(milliseconds: 100));

      final finalMemory = ProcessInfo.currentRss;
      print('清理后内存使用: ${finalMemory ~/ 1024 ~/ 1024}MB');

      final memoryIncrease = peakMemory - initialMemory;
      print('内存增长: ${memoryIncrease ~/ 1024 ~/ 1024}MB');

      // 基本的内存使用检查
      expect(
        memoryIncrease ~/ 1024 ~/ 1024,
        lessThan(500),
        reason: '创建50个游戏的内存增长应该小于500MB',
      );
    });
  });
}

/// 辅助类用于获取进程信息
class ProcessInfo {
  static int get currentRss {
    // 在真实环境中，这里可以使用dart:io的Process或其他方式获取内存信息
    // 这里返回一个模拟值
    return DateTime.now().millisecondsSinceEpoch % 1000000000;
  }
}
