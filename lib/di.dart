import 'package:get_it/get_it.dart';
import 'package:werewolf_arena/page/bootstrap/bootstrap_view_model.dart';
import 'package:werewolf_arena/page/debug/debug_view_model.dart';
import 'package:werewolf_arena/page/home/home_view_model.dart';
import 'package:werewolf_arena/page/game/game_view_model.dart';
import 'package:werewolf_arena/page/settings/settings_view_model.dart';
import 'package:werewolf_arena/page/settings/llm_config_view_model.dart';
import 'package:werewolf_arena/services/config_service.dart';
import 'package:werewolf_arena/services/game_service.dart';

/// 依赖注入配置
///
/// 基于新架构的依赖注入配置：
/// - 使用GameAssembler外部组装游戏，而不是在DI中管理GameEngine
/// - 保持原有的服务层和ViewModel注册
/// - 简化配置，专注于真正需要全局管理的组件
class DI {
  /// 初始化依赖注入容器
  ///
  /// 注册所有需要依赖注入的服务和ViewModel：
  /// - ConfigService: 配置管理服务（单例）
  /// - GameService: 游戏服务（单例，使用GameAssembler）
  /// - ViewModel: 页面视图模型（工厂模式）
  static void ensureInitialized() {
    // 注册核心服务（单例）
    GetIt.instance.registerLazySingleton<ConfigService>(() => ConfigService());
    GetIt.instance.registerLazySingleton<GameService>(() => GameService());

    // 注册页面ViewModel（工厂模式）
    GetIt.instance.registerLazySingleton<BootstrapViewModel>(
      () => BootstrapViewModel(),
    );
    GetIt.instance.registerFactory<HomeViewModel>(() => HomeViewModel());
    GetIt.instance.registerFactory<GameViewModel>(() => GameViewModel());
    GetIt.instance.registerFactory<SettingsViewModel>(
      () => SettingsViewModel(),
    );
    GetIt.instance.registerFactory<LLMConfigViewModel>(
      () => LLMConfigViewModel(),
    );
    GetIt.instance.registerFactory<DebugViewModel>(() => DebugViewModel());
  }

  /// 清理依赖注入容器
  ///
  /// 用于测试和应用关闭时的资源清理
  static Future<void> dispose() async {
    await GetIt.instance.reset();
  }

  /// 获取依赖注入容器实例
  ///
  /// 便捷方法，用于在代码中获取注册的服务
  static GetIt get instance => GetIt.instance;

  /// 检查服务是否已注册
  ///
  /// 用于调试和测试
  static bool isRegistered<T extends Object>() {
    return GetIt.instance.isRegistered<T>();
  }
}
