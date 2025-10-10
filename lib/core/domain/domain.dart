/// Domain层统一导出文件
///
/// 包含所有领域模型: 实体、值对象、枚举

// 实体 - 隐藏重复定义的类型,使用value_objects和enums中的定义
export 'entities/player.dart';
export 'entities/ai_player.dart';
export 'entities/role.dart';

// 值对象
export 'value_objects/game_phase.dart';
export 'value_objects/game_status.dart';
export 'value_objects/game_event_type.dart';
export 'value_objects/event_visibility.dart';
export 'value_objects/death_cause.dart';
export 'value_objects/skill_type.dart';
export 'value_objects/vote_type.dart';
export 'value_objects/speech_type.dart';
export 'value_objects/player_model_config.dart';
export 'value_objects/ai_personality.dart';

// 枚举
export 'enums/player_type.dart';
export 'enums/role_type.dart';
export 'enums/role_alignment.dart';
