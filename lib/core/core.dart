/// Core模块统一导出文件
///
/// 这是整个游戏引擎核心的对外接口

// Domain层 - 领域模型
export 'domain/domain.dart';

// Events层 - 事件系统
export 'events/events.dart';

// State层 - 状态管理
export 'state/game_state.dart';

// Engine层 - 游戏引擎
export 'engine/game_engine.dart';
export 'engine/game_observer.dart';
export 'engine/game_parameters.dart';

// Scenarios层 - 游戏场景
export 'scenarios/scenarios.dart';

// Rules层 - 游戏规则
export 'rules/logic_validator.dart';
