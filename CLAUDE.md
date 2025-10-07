# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 重要工作规则 (最高优先级)

**1. 语言要求**：永远使用中文回答所有问题和进行交流。

**2. 第三方包使用规范**：在使用任何 Dart 第三方包之前，必须先通过 context7 这个 MCP 工具获取最新的文档知识和 API 使用模式。不依赖记忆中的过时信息。

**3. 游戏执行限制**：绝对不要尝试执行 `dart bin/werewolf_arena.dart` 来测试程序运行情况。该程序执行时间很长（6-10分钟），且会消耗大量 token。只使用静态分析、编译检查和单元测试来验证代码。

## Project Overview

Werewolf Arena is a command-line Werewolf (Mafia) game with AI players powered by LLMs. The game simulates classic Werewolf gameplay with different roles (werewolves, villagers, seer, witch, hunter, guard) where AI players make decisions during night and day phases.

## Development Commands

### Running the Game
```bash
# Run with default configuration
dart run bin/werewolf_arena.dart

# Run with custom config file
dart run bin/werewolf_arena.dart --config config/custom_config.yaml

# Run with specific player count
dart run bin/werewolf_arena.dart --players 8

# Enable debug mode
dart run bin/werewolf_arena.dart --debug
```

### Development Tasks
```bash
# Install dependencies
dart pub get

# Run static analysis
dart analyze

# Run all tests
dart test

# Run specific test file
dart test test/game_event_test.dart

# Generate code (for JSON serialization)
dart run build_runner build

# Watch for changes and rebuild
dart run build_runner watch
```

## Architecture

### Core Components

**Game Engine (`lib/game/game_engine.dart`)**: Central orchestrator managing game flow, phases (night/day/voting), and state transitions. Controls the complete game loop from initialization through end conditions.

**Game State (`lib/game/game_state.dart`)**: Maintains current game state including players, phase, events, and victory conditions. Tracks all game data and provides state queries.

**Event System (`lib/game/game_event.dart`)**: Event-driven architecture where all game actions (kills, votes, speeches) are represented as events with visibility rules determining what each player can see.

**AI Players (`lib/player/ai_player.dart`)**: LLM-powered players that make decisions based on their role and game context. Uses prompt templates and game state analysis for realistic gameplay.

**Role System (`lib/player/role.dart`)**: Defines different player roles (Werewolf, Seer, Witch, etc.) with specific abilities and win conditions. Each role has unique night actions and behaviors.

**LLM Integration (`lib/llm/llm_service.dart`, `lib/llm/prompt_manager.dart`)**: Handles communication with language models for AI decision-making and maintains context-aware prompts.

### Key Patterns

- **Event-driven**: All game actions create events that are processed and stored in game history
- **Phase-based**: Game progresses through distinct phases (night → day → voting) with different available actions
- **Role-specific behavior**: Each role type has unique capabilities and decision-making logic
- **State isolation**: Players only see events they're allowed to see based on game rules

### Configuration

Game behavior is controlled through YAML configuration files in `config/`:
- `default_config.yaml`: Main configuration with role distribution, LLM settings, timing
- Role counts, game timing, LLM models, and action order can be customized
- Supports both sequential (numbered) and random player action ordering

### Testing

Tests focus on:
- Event visibility rules (`test/game_event_visibility_test.dart`)
- Game event creation and processing (`test/game_event_test.dart`)
- Core game logic validation

The codebase uses mocktail for mocking in tests and includes comprehensive event system testing.