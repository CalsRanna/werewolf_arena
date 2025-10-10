import 'dart:io';
import 'console_output.dart';

/// 控制台程序配置文件自检和引导工具
class ConsoleConfigHelper {
  static const String configFileName = 'werewolf_config.yaml';

  final GameConsole _console = GameConsole.instance;

  /// 输出彩色文本
  void _printColored(String text, ConsoleColor color) {
    if (!stdout.hasTerminal) {
      _console.printLine(text);
      return;
    }

    final colorCode = _getColorCode(color);
    _console.printLine('\x1B[${colorCode}m$text\x1B[0m');
  }

  int _getColorCode(ConsoleColor color) {
    switch (color) {
      case ConsoleColor.red:
        return 31;
      case ConsoleColor.green:
        return 32;
      case ConsoleColor.yellow:
        return 33;
      case ConsoleColor.blue:
        return 34;
      case ConsoleColor.magenta:
        return 35;
      case ConsoleColor.cyan:
        return 36;
      case ConsoleColor.white:
        return 37;
      case ConsoleColor.gray:
        return 90;
      case ConsoleColor.bold:
        return 1;
    }
  }

  /// 检查并初始化配置文件
  ///
  /// 返回配置文件所在目录，如果失败返回 null
  Future<String?> ensureConfigFiles() async {
    // 获取可执行文件所在目录
    final executablePath = Platform.resolvedExecutable;
    final executableDir = File(executablePath).parent.path;

    _console.printLine('📁 可执行文件目录: $executableDir');
    _console.printLine();

    // 检查配置文件是否存在
    final configFile = File('$executableDir/$configFileName');
    final configExists = await configFile.exists();

    if (configExists) {
      _printColored('✅ 配置文件检查通过', ConsoleColor.green);
      _console.printLine('   - $configFileName');
      _console.printLine();
      return executableDir;
    }

    // 配置文件不存在，需要生成
    _printColored('⚠️  配置文件缺失: $configFileName', ConsoleColor.yellow);
    _console.printLine();

    // 询问用户是否生成
    stdout.write('是否自动生成默认配置文件？(Y/n): ');
    final input = stdin.readLineSync()?.trim().toLowerCase();

    if (input != null && input.isNotEmpty && input != 'y' && input != 'yes') {
      _printColored('❌ 用户取消配置文件生成', ConsoleColor.red);
      return null;
    }

    // 生成配置文件
    try {
      await _generateConfig(configFile);

      _console.printLine();
      _console.printSeparator('=', 60);
      _printColored('✅ 配置文件生成成功！', ConsoleColor.green);
      _console.printSeparator('=', 60);
      _console.printLine();
      _printColored('📝 下一步操作指南:', ConsoleColor.cyan);
      _console.printLine();
      _console.printLine('1. 编辑 $configFileName 配置 LLM:');
      _console.printLine('   - ⚠️  必须: 修改 default_llm.api_key 为你的实际 API Key');
      _console.printLine('   - 可选: 修改 default_llm.model 选择不同的模型');
      _console.printLine('   - 可选: 为不同玩家配置专属模型（player_models 部分）');
      _console.printLine('     每个玩家配置只需 model、api_key、base_url 三项');
      _console.printLine();
      _console.printLine('2. 可选: 调整日志配置（logging 部分）');
      _console.printLine();
      _console.printLine('3. 配置完成后，重新运行程序开始游戏');
      _console.printLine();
      _console.printLine('注意: ui 和 development 配置仅用于兼容性，console 程序不使用');
      _console.printLine();
      _console.printSeparator('=', 60);

      return executableDir;
    } catch (e) {
      _console.displayError('生成配置文件失败: $e');
      return null;
    }
  }

  /// 生成统一配置文件
  Future<void> _generateConfig(File file) async {
    _console.printLine('📝 正在生成 $configFileName...');

    final content = '''# 狼人杀竞技场 - 控制台程序配置文件

# ============================================================================
# LLM 配置（语言模型）
# ============================================================================

# 默认 LLM 配置
# ⚠️  重要：请将 YOUR_KEY_HERE 替换为你的实际 API Key
default_llm:
  model: "deepseek/deepseek-chat-v3.1"
  api_key: "YOUR_KEY_HERE"
  base_url: "https://openrouter.ai/api/v1"
  timeout_seconds: 30
  max_retries: 3

# 玩家专属模型配置（可选）
# 如果不配置，所有玩家将使用 default_llm
# 配置后，对应编号的玩家将使用指定的模型
player_models:
  "1":
    model: "deepseek/deepseek-v3.2-exp"
    api_key: "YOUR_KEY_HERE"
    base_url: "https://openrouter.ai/api/v1"

  "2":
    model: "anthropic/claude-sonnet-4.5"
    api_key: "YOUR_KEY_HERE"
    base_url: "https://openrouter.ai/api/v1"

  "3":
    model: "deepseek/deepseek-chat-v3.1"
    api_key: "YOUR_KEY_HERE"
    base_url: "https://openrouter.ai/api/v1"

  "4":
    model: "deepseek/deepseek-r1-0528"
    api_key: "YOUR_KEY_HERE"
    base_url: "https://openrouter.ai/api/v1"

  "5":
    model: "deepseek/deepseek-chat-v3-0324"
    api_key: "YOUR_KEY_HERE"
    base_url: "https://openrouter.ai/api/v1"

  "6":
    model: "anthropic/claude-sonnet-4"
    api_key: "YOUR_KEY_HERE"
    base_url: "https://openrouter.ai/api/v1"

  "7":
    model: "anthropic/claude-3.5-sonnet"
    api_key: "YOUR_KEY_HERE"
    base_url: "https://openrouter.ai/api/v1"

  "8":
    model: "openai/gpt-5"
    api_key: "YOUR_KEY_HERE"
    base_url: "https://openrouter.ai/api/v1"

  "9":
    model: "openai/o3"
    api_key: "YOUR_KEY_HERE"
    base_url: "https://openrouter.ai/api/v1"

  "10":
    model: "google/gemini-2.5-pro"
    api_key: "YOUR_KEY_HERE"
    base_url: "https://openrouter.ai/api/v1"

  "11":
    model: "x-ai/grok-4"
    api_key: "YOUR_KEY_HERE"
    base_url: "https://openrouter.ai/api/v1"

  "12":
    model: "qwen/qwen3-max"
    api_key: "YOUR_KEY_HERE"
    base_url: "https://openrouter.ai/api/v1"

# ============================================================================
# 日志配置
# ============================================================================
logging:
  level: "info"
  enable_console: true
  enable_file: true
  backup_count: 5
''';

    await file.writeAsString(content);
    _printColored('   ✅ $configFileName 已生成', ConsoleColor.green);
  }
}
