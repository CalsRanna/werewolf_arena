import 'dart:io';
import 'package:args/args.dart';

/// Console adapter for running the game in terminal mode
class ConsoleAdapter {
  ConsoleAdapter();

  Future<void> runConsoleMode(List<String> arguments) async {
    try {
      // 解析命令行参数
      final parser = ArgParser()
        ..addOption('config', abbr: 'c', help: '配置文件路径')
        ..addOption('players', abbr: 'p', help: '玩家数量')
        ..addFlag('debug', abbr: 'd', help: '启用调试模式', defaultsTo: false)
        ..addFlag('help', abbr: 'h', help: '显示帮助信息', negatable: false);

      final ArgResults argResults;
      try {
        argResults = parser.parse(arguments);
      } catch (e) {
        print('错误: 无效的命令行参数\n');
        _printHelp(parser);
        exit(1);
      }

      if (argResults['help'] as bool) {
        _printHelp(parser);
        return;
      }

      print('========================================');
      print('      狼人杀竞技场 - 控制台模式      ');
      print('========================================\n');

      // TODO: 实现游戏逻辑
      // 1. 加载配置
      // 2. 初始化游戏引擎
      // 3. 创建玩家
      // 4. 开始游戏循环
      // 5. 显示游戏结果

      print('控制台模式正在开发中...');
      print('请使用 Flutter GUI 模式运行游戏。');
      print('\n提示: 运行 "flutter run -d macos" 或其他平台来启动 GUI 应用。');

    } catch (e, stackTrace) {
      print('错误: $e');
      print('堆栈跟踪: $stackTrace');
      exit(1);
    }
  }

  void _printHelp(ArgParser parser) {
    print('狼人杀竞技场 - 控制台模式');
    print('');
    print('用法: dart run bin/console.dart [选项]');
    print('');
    print('选项:');
    print(parser.usage);
  }
}
