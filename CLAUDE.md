# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
This is a Werewolf LLM game console program developed with Dart. It uses Large Language Models (LLM) to play different game roles, providing a complete Werewolf game experience.

## Development Commands

### Build and Run
```bash
# Install dependencies
dart pub get

# Run main program
dart run bin/werewolf_arena.dart

# Run tests
dart test

# Code analysis (lint check)
dart analyze

# Format code
dart format .
```

### Testing
```bash
# Run all tests
dart test

# Run specific test file
dart test test/werewolf_arena_test.dart

# Run tests with verbose output
dart test -v
```

## Code Architecture

### Core Module Structure
```
lib/
├── werewolf_arena.dart     # Main library file (simple calculation function)
├── game/                   # Game core logic
│   ├── game_engine.dart    # Game engine - controls entire game flow
│   ├── game_state.dart     # Game state management
│   └── game_action.dart    # Game action definitions
├── player/                 # Player system
│   ├── player.dart         # Player base class
│   ├── ai_player.dart      # AI player implementation
│   ├── judge.dart          # Judge role
│   └── role.dart           # Role definitions (werewolf, villager, seer, etc.)
├── llm/                    # LLM integration
│   ├── llm_service.dart    # LLM service interface (OpenAI/OpenRouter)
│   └── prompt_manager.dart # Prompt management
├── ui/                     # User interface
│   └── console_ui.dart     # Console interface
└── utils/                  # Utility classes
    ├── game_logger.dart    # Game logging
    ├── config_loader.dart  # Configuration loading
    └── random_helper.dart  # Random number helper
```

### Game Engine Design
- **GameEngine** (`lib/game/game_engine.dart`): Core game loop controller, manages game phase transitions
- **Game Phases**: Night → Day → Voting → Night (cycle)
- **Action Order**: Werewolf → Guard → Seer → Witch (night), Player speeches → Voting (day)
- **Event-driven**: Uses StreamController to broadcast game events and state changes

### LLM Integration Architecture
- **LLMService** abstract interface, supports multiple LLM providers
- **OpenAIService** implementation, uses OpenRouter API
- **Response Caching**: Avoids duplicate requests
- **Error Handling**: Automatic retry and fallback handling

### Role System
- **Role Base Class**: Defines basic role attributes and abilities
- **Special Roles**: WerewolfRole, SeerRole, WitchRole, GuardRole, HunterRole
- **Skill System**: Each role has specific night skills and day behaviors

## Important Configuration

### LLM Configuration
- API key configuration in `config/` directory
- Supports OpenAI API and OpenRouter
- Default model: `gpt-3.5-turbo`

### Game Configuration
- Player count: 8-12 players
- Role allocation: 2-3 werewolves, 3-5 villagers, several god roles
- Action order: Configurable sequential or random

## Development Notes

### Game Flow Control
- Game engine uses step-by-step execution mode, controlled by UI
- `executeGameStep()` method advances game to next phase
- Avoid automatic game loops, maintain user control

### LLM Interaction
- All AI decisions go through `generateAction()` method
- Role statements go through `generateStatement()` method
- Use structured prompts to ensure AI returns valid game actions

### Error Handling
- Automatic retry when LLM calls fail
- Player action failures don't stop the game
- Detailed error logging

### Testing Strategy
- Unit tests cover core game logic
- Integration tests verify game flow
- Mock LLM service for deterministic testing

## Extension Points

### Adding New Roles
1. Define new role class in `lib/player/role.dart`
2. Add corresponding actions in `lib/game/game_action.dart`
3. Add role-specific processing logic in game engine
4. Update prompt manager

### LLM Providers
- Implement `LLMService` interface
- Add new implementation in `lib/llm/llm_service.dart`
- Configure corresponding API keys and endpoints

### UI Interface
- Currently console interface, can be extended to graphical interface
- UI is completely separated from game logic, easy to replace

## Project Status
Based on the PRD document, this is a console program that implements complete Werewolf game logic, supporting AI players to perform role-playing and game decision-making through LLM.