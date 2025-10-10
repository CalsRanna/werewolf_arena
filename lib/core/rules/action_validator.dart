import 'package:werewolf_arena/core/state/game_state.dart';
import 'package:werewolf_arena/core/domain/entities/player.dart';
import 'package:werewolf_arena/core/domain/enums/role_type.dart';

/// 行动验证器
///
/// 负责验证游戏中各种行动的合法性，包括：
/// - 玩家是否存活且可以行动
/// - 角色技能使用条件
/// - 特殊行动规则（如守卫不能连续守护同一人）
/// - 行动目标的合法性
class ActionValidator {
  /// 验证玩家是否可以执行行动
  ///
  /// [player] 执行行动的玩家
  /// [state] 当前游戏状态
  /// 返回验证结果和原因
  ValidationResult validateCanPlayerAct(Player player, GameState state) {
    // 检查玩家是否存活
    if (!player.isAlive) {
      return ValidationResult.invalid('玩家 ${player.name} 已死亡，无法行动');
    }

    // 检查游戏是否正在运行
    if (!state.isPlaying) {
      return ValidationResult.invalid('游戏未开始或已结束，无法行动');
    }

    // 检查角色是否可以使用技能
    if (!_canRoleUseSkill(player)) {
      return ValidationResult.invalid('角色 ${player.role.name} 无法使用技能');
    }

    return ValidationResult.valid();
  }

  /// 验证守护行动
  ///
  /// [guard] 守卫玩家
  /// [target] 守护目标
  /// [state] 当前游戏状态
  /// 返回验证结果
  ValidationResult validateGuardAction(Player guard, Player target, GameState state) {
    // 基本验证
    final basicValidation = validateCanPlayerAct(guard, state);
    if (!basicValidation.isValid) {
      return basicValidation;
    }

    // 检查目标是否存活
    if (!target.isAlive) {
      return ValidationResult.invalid('守护目标 ${target.name} 已死亡');
    }

    // 检查是否连续守护同一人
    if (_isGuardingSamePlayerConsecutively(guard, target, state)) {
      return ValidationResult.invalid('不能连续两晚守护同一玩家 ${target.name}');
    }

    return ValidationResult.valid();
  }

  /// 验证预言家查验行动
  ///
  /// [seer] 预言家玩家
  /// [target] 查验目标
  /// [state] 当前游戏状态
  /// 返回验证结果
  ValidationResult validateSeerAction(Player seer, Player target, GameState state) {
    // 基本验证
    final basicValidation = validateCanPlayerAct(seer, state);
    if (!basicValidation.isValid) {
      return basicValidation;
    }

    // 检查目标是否存活
    if (!target.isAlive) {
      return ValidationResult.invalid('查验目标 ${target.name} 已死亡');
    }

    // 预言家不能查验自己
    if (seer == target) {
      return ValidationResult.invalid('预言家不能查验自己');
    }

    // 检查是否已经查验过该玩家（可选规则）
    if (_hasAlreadyInvestigated(seer, target, state)) {
      return ValidationResult.invalid('已经查验过玩家 ${target.name}');
    }

    return ValidationResult.valid();
  }

  /// 验证女巫解药行动
  ///
  /// [witch] 女巫玩家
  /// [target] 解救目标
  /// [state] 当前游戏状态
  /// 返回验证结果
  ValidationResult validateWitchHealAction(Player witch, Player target, GameState state) {
    // 基本验证
    final basicValidation = validateCanPlayerAct(witch, state);
    if (!basicValidation.isValid) {
      return basicValidation;
    }

    // 检查是否有解药
    if (!_witchHasAntidote(witch, state)) {
      return ValidationResult.invalid('女巫没有解药');
    }

    // 检查目标是否是被击杀的玩家
    if (!_isTonightVictim(target, state)) {
      return ValidationResult.invalid('目标 ${target.name} 今晚未被击杀');
    }

    return ValidationResult.valid();
  }

  /// 验证女巫毒药行动
  ///
  /// [witch] 女巫玩家
  /// [target] 毒杀目标
  /// [state] 当前游戏状态
  /// 返回验证结果
  ValidationResult validateWitchPoisonAction(Player witch, Player target, GameState state) {
    // 基本验证
    final basicValidation = validateCanPlayerAct(witch, state);
    if (!basicValidation.isValid) {
      return basicValidation;
    }

    // 检查是否有毒药
    if (!_witchHasPoison(witch, state)) {
      return ValidationResult.invalid('女巫没有毒药');
    }

    // 检查目标是否存活
    if (!target.isAlive) {
      return ValidationResult.invalid('毒杀目标 ${target.name} 已死亡');
    }

    return ValidationResult.valid();
  }

  /// 验证狼人击杀行动
  ///
  /// [werewolf] 狼人玩家
  /// [target] 击杀目标
  /// [state] 当前游戏状态
  /// 返回验证结果
  ValidationResult validateWerewolfKillAction(Player werewolf, Player target, GameState state) {
    // 基本验证
    final basicValidation = validateCanPlayerAct(werewolf, state);
    if (!basicValidation.isValid) {
      return basicValidation;
    }

    // 检查是否是狼人角色
    if (!werewolf.role.isWerewolf) {
      return ValidationResult.invalid('玩家 ${werewolf.name} 不是狼人，无法执行击杀');
    }

    // 检查目标是否存活
    if (!target.isAlive) {
      return ValidationResult.invalid('击杀目标 ${target.name} 已死亡');
    }

    // 检查目标是否是狼人同伴
    if (target.role.isWerewolf) {
      return ValidationResult.invalid('狼人不能击杀同伴 ${target.name}');
    }

    return ValidationResult.valid();
  }

  /// 验证猎人开枪行动
  ///
  /// [hunter] 猎人玩家
  /// [target] 开枪目标
  /// [state] 当前游戏状态
  /// 返回验证结果
  ValidationResult validateHunterShootAction(Player hunter, Player target, GameState state) {
    // 检查是否是猎人角色
    if (!_isHunterRole(hunter)) {
      return ValidationResult.invalid('玩家 ${hunter.name} 不是猎人');
    }

    // 检查猎人是否已开枪
    if (_hasHunterShot(hunter, state)) {
      return ValidationResult.invalid('猎人已经开过枪');
    }

    // 检查目标是否存活
    if (!target.isAlive) {
      return ValidationResult.invalid('开枪目标 ${target.name} 已死亡');
    }

    // 检查猎人是否处于死亡状态（触发技能条件）
    if (!_isHunterDead(hunter, state)) {
      return ValidationResult.invalid('猎人必须死亡才能开枪');
    }

    return ValidationResult.valid();
  }

  /// 验证投票行动
  ///
  /// [voter] 投票玩家
  /// [target] 投票目标
  /// [state] 当前游戏状态
  /// 返回验证结果
  ValidationResult validateVoteAction(Player voter, Player target, GameState state) {
    // 检查投票者是否存活
    if (!voter.isAlive) {
      return ValidationResult.invalid('投票者 ${voter.name} 已死亡');
    }

    // 检查是否是投票阶段
    if (!state.isVoting) {
      return ValidationResult.invalid('当前不是投票阶段');
    }

    // 检查目标是否存活
    if (!target.isAlive) {
      return ValidationResult.invalid('投票目标 ${target.name} 已死亡');
    }

    // 检查是否已经投过票
    if (_hasAlreadyVoted(voter, state)) {
      return ValidationResult.invalid('玩家 ${voter.name} 已经投过票');
    }

    // 检查是否可以投票给自己（可选规则）
    if (_cannotVoteSelf && voter == target) {
      return ValidationResult.invalid('不能投票给自己');
    }

    return ValidationResult.valid();
  }

  /// 获取角色的有效行动目标列表
  ///
  /// [player] 行动玩家
  /// [state] 当前游戏状态
  /// 返回有效目标列表
  List<Player> getValidActionTargets(Player player, GameState state) {
    final validTargets = <Player>[];

    if (!player.isAlive || !state.isPlaying) {
      return validTargets;
    }

    for (final target in state.alivePlayers) {
      if (_isValidTargetForRole(player, target, state)) {
        validTargets.add(target);
      }
    }

    return validTargets;
  }

  // 私有辅助方法

  /// 检查是否连续守护同一玩家
  bool _isGuardingSamePlayerConsecutively(Player guard, Player target, GameState state) {
    final guardKey = 'guard_${guard.name}_last_protected';
    final lastProtectedName = state.metadata[guardKey] as String?;

    if (lastProtectedName != null && lastProtectedName == target.name) {
      return true;
    }

    return false;
  }

  /// 检查是否已经查验过
  bool _hasAlreadyInvestigated(Player seer, Player target, GameState state) {
    final seerKey = 'seer_${seer.name}_investigated';
    final investigated = state.metadata[seerKey] as List<String>? ?? [];
    return investigated.contains(target.name);
  }

  /// 检查女巫是否有解药
  bool _witchHasAntidote(Player witch, GameState state) {
    final witchKey = 'witch_${witch.name}_has_antidote';
    return state.metadata[witchKey] as bool? ?? true;
  }

  /// 检查女巫是否有毒药
  bool _witchHasPoison(Player witch, GameState state) {
    final witchKey = 'witch_${witch.name}_has_poison';
    return state.metadata[witchKey] as bool? ?? true;
  }

  /// 检查目标是否是今晚的受害者
  bool _isTonightVictim(Player target, GameState state) {
    return state.nightActions.tonightVictim == target;
  }

  /// 检查是否是猎人角色
  bool _isHunterRole(Player player) {
    return player.role.runtimeType.toString().toLowerCase().contains('hunter');
  }

  /// 检查猎人是否已开枪
  bool _hasHunterShot(Player hunter, GameState state) {
    final hunterKey = 'hunter_${hunter.name}_has_shot';
    return state.metadata[hunterKey] as bool? ?? false;
  }

  /// 检查猎人是否死亡
  bool _isHunterDead(Player hunter, GameState state) {
    return !hunter.isAlive;
  }

  /// 检查是否已经投过票
  bool _hasAlreadyVoted(Player voter, GameState state) {
    return state.votingState.votes.containsKey(voter.name);
  }

  /// 检查目标对角色是否有效
  bool _isValidTargetForRole(Player player, Player target, GameState state) {
    final role = player.role;

    // 狼人不能击杀同伴
    if (role.isWerewolf && target.role.isWerewolf) {
      return false;
    }

    // 预言家不能查验自己
    if (role.runtimeType.toString().toLowerCase().contains('seer') && player == target) {
      return false;
    }

    // 守卫不能连续守护同一人
    if (role.runtimeType.toString().toLowerCase().contains('guard')) {
      return !_isGuardingSamePlayerConsecutively(player, target, state);
    }

    return true;
  }

  /// 配置：是否可以投票给自己
  bool get _cannotVoteSelf => false; // 默认可以投票给自己

  /// 检查角色是否可以使用技能
  bool _canRoleUseSkill(Player player) {
    // 村民没有技能
    if (player.role.type == RoleType.villager) {
      return false;
    }

    // 其他角色默认都可以使用技能
    // 具体的技能使用限制在各自的验证方法中检查
    return true;
  }
}

/// 验证结果类
class ValidationResult {
  final bool isValid;
  final String? reason;

  const ValidationResult._(this.isValid, this.reason);

  /// 创建有效的验证结果
  factory ValidationResult.valid() => const ValidationResult._(true, null);

  /// 创建无效的验证结果
  factory ValidationResult.invalid(String reason) => ValidationResult._(false, reason);

  @override
  String toString() {
    if (isValid) {
      return 'ValidationResult.valid()';
    } else {
      return 'ValidationResult.invalid($reason)';
    }
  }
}