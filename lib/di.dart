import 'package:get_it/get_it.dart';
import 'package:werewolf_arena/page/bootstrap/bootstrap_view_model.dart';
import 'package:werewolf_arena/page/home/home_view_model.dart';
import 'package:werewolf_arena/page/game/game_view_model.dart';
import 'package:werewolf_arena/page/settings/settings_view_model.dart';
import 'package:werewolf_arena/services/config_service.dart';
import 'package:werewolf_arena/services/llm_service.dart';
import 'package:werewolf_arena/services/game_service.dart';

class DI {
  static void ensureInitialized() {
    // 单例服务
    GetIt.instance.registerLazySingleton<ConfigService>(
      () => ConfigService(),
    );
    GetIt.instance.registerLazySingleton<LLMService>(
      () => LLMService(),
    );
    GetIt.instance.registerLazySingleton<GameService>(
      () => GameService(),
    );

    // ViewModel (工厂模式)
    GetIt.instance.registerLazySingleton<BootstrapViewModel>(
      () => BootstrapViewModel(),
    );
    GetIt.instance.registerFactory<HomeViewModel>(() => HomeViewModel());
    GetIt.instance.registerFactory<GameViewModel>(() => GameViewModel());
    GetIt.instance.registerFactory<SettingsViewModel>(() => SettingsViewModel());
  }
}