import 'package:werewolf_arena/engine/skill/game_skill.dart';

/// 游戏角色抽象基类
///
/// 定义角色能力、技能和行为，成为完整的角色实体
abstract class GameRole {
  String get description;
  // 基础信息
  String get id;
  String get name;

  // 角色身份提示词
  String get prompt; // 定义角色身份和阵营目标

  // 技能系统
  List<GameSkill> get skills;
}
