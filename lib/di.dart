import 'package:get_it/get_it.dart';
import 'package:werewolf_arena/page/bootstrap/bootstrap_view_model.dart';
import 'package:werewolf_arena/page/debug/debug_view_model.dart';
import 'package:werewolf_arena/page/home/home_view_model.dart';
import 'package:werewolf_arena/page/game/game_view_model.dart';
import 'package:werewolf_arena/page/player_intelligence_detail/player_intelligence_detail_view_model.dart';
import 'package:werewolf_arena/page/settings/settings_view_model.dart';
import 'package:werewolf_arena/page/player_intelligence/player_intelligence_view_model.dart';

class DI {
  static void ensureInitialized() {
    GetIt.instance.registerLazySingleton<BootstrapViewModel>(
      () => BootstrapViewModel(),
    );
    GetIt.instance.registerFactory<HomeViewModel>(() => HomeViewModel());
    GetIt.instance.registerFactory<GameViewModel>(() => GameViewModel());
    GetIt.instance.registerFactory<SettingsViewModel>(
      () => SettingsViewModel(),
    );
    GetIt.instance.registerLazySingleton<PlayerIntelligenceViewModel>(
      () => PlayerIntelligenceViewModel(),
    );
    GetIt.instance.registerFactory<PlayerIntelligenceDetailViewModel>(
      () => PlayerIntelligenceDetailViewModel(),
    );
    GetIt.instance.registerFactory<DebugViewModel>(() => DebugViewModel());
  }
}
