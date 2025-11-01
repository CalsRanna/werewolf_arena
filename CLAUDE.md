# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Werewolf Arena (狼人杀竞技场) is an AI-powered Werewolf (Mafia) game where LLM-based agents compete against each other. The project is built with Flutter/Dart and supports both a GUI application and a console mode.

**Repository:** https://github.com/cals/werewolf_arena

## Running the Application

### Console Mode
```bash
# Run with default settings (random human player assignment)
dart run bin/main.dart

# God mode (all AI players, observe everything)
dart run bin/main.dart -g

# Play as specific player (1-12)
dart run bin/main.dart --player 1

# Enable debug mode
dart run bin/main.dart -d

# God mode with debug
dart run bin/main.dart -g -d
```

### Flutter GUI
```bash
# Run the Flutter application
flutter run

# For desktop platforms
flutter run -d macos  # or windows/linux
```

### Development Commands
```bash
# Install dependencies
flutter pub get

# Run code generation (for auto_route, json_serializable, etc.)
flutter pub run build_runner build --delete-conflicting-outputs

# Run linter
flutter analyze

# Run tests
flutter test

# Run a single test file
flutter test test/widget_test.dart
```

## Architecture

### Core Engine (`lib/engine/`)

The game engine is the heart of the application and follows a modular, event-driven architecture:

**Game Flow:**
1. **GameEngine** (`game_engine.dart`) - Main coordinator that manages game lifecycle
   - Initializes game state with players and scenario
   - Runs the main game loop via `loop()` method
   - Uses **GameRoundController** to process each phase
   - Emits events to **GameObserver** for UI updates

2. **GameState** (`game_state.dart`) - Central state container
   - Tracks players, day count, phase, deaths, votes
   - Maintains event stream for observers
   - Checks win conditions

3. **GameRoundController** (`game_round/`) - Phase execution
   - **DefaultGameRoundController** executes night/day/vote phases sequentially
   - Each phase involves players casting skills in appropriate order

**Player System:**
- **GamePlayer** (`player/game_player.dart`) - Abstract base class with common properties
  - **AIPlayer** - LLM-controlled player using reasoning engine
  - **HumanPlayer** - Human-controlled player with interactive UI

**Player Driver Pattern:**
- **PlayerDriver** (`driver/`) - Strategy pattern for player decision-making
  - **AIPlayerDriver** - Coordinates with AIReasoningEngine for LLM decisions
  - **HumanPlayerDriver** - Handles human input via UI interface
  - Drivers are injected into players, enabling easy testing and different control modes

**AI Reasoning System (`reasoning/`):**

The AI uses a multi-step reasoning pipeline executed by **AIReasoningEngine**:

1. **FactAnalysisStep** - Analyze observable facts and events
2. **IdentityInferenceStep** - Deduce player identities based on behavior
3. **MaskSelectionStep** - Choose behavioral "mask" (persona) for this turn
4. **PlaybookSelectionStep** - Select tactical playbook to follow
5. **StrategyPlanningStep** - Plan concrete actions for current phase
6. **SpeechGenerationStep** - Generate in-character speech
7. **SelfReflectionStep** - Reflect on performance and adjust strategy

Each step receives a **ReasoningContext** and produces a **ReasoningResult**. Steps can be skipped based on conditions.

**Memory & Social Analysis (`memory/`):**
- **WorkingMemory** - Stores observations, inferences, relationship data
- **SocialNetwork** - Tracks trust/suspicion relationships between players
- **SocialAnalyzer** - Analyzes social dynamics and player behavior patterns
- **InformationFilter** - Filters information based on player's role/knowledge

**Role System (`role/`):**
- Abstract **GameRole** base class
- Concrete roles: Werewolf, Seer, Witch, Guard, Hunter, Villager
- Each role defines faction, skills, and abilities

**Skill System (`skill/`):**
- **GameSkill** - Abstract skill interface
- Skills: Kill, Investigate, Heal, Poison, Protect, Vote, Discuss, Conspire, Testament, Shoot
- Skills return **SkillResult** containing targets and effects

**Tactical Systems:**

- **Playbook** (`playbook/`) - Strategic templates for complex multi-phase tactics
  - Examples: WerewolfJumpSeerPlaybook, GuardProtectPlaybook, WitchHidePoisonPlaybook
  - Define core goals, execution steps, key phrases, and success criteria
  - Selected during PlaybookSelectionStep based on game state

- **RoleMask** (`mask/`) - Behavioral personas that affect speech style
  - Examples: AggressiveAttacker, CalmAnalyst, ConfusedNovice, Peacemaker
  - Define tone, language style, and example phrases
  - Selected during MaskSelectionStep to add variety to player behavior

**Event System (`event/`):**
- All game actions emit events (GameEvent subclasses)
- Events: GameStart, Kill, Heal, Poison, Protect, Investigate, Discuss, Vote, Exile, Dead, GameEnd
- **GameObserver** receives events for UI updates and logging

**Scenario System (`scenario/`):**
- **GameScenario** defines player count and role distribution
- **Scenario12Players** - 12-player configuration with standard role mix

### Configuration System

**GameConfig** (`engine/game_config.dart`):
- Contains list of **PlayerIntelligence** objects (one per player)
- Each PlayerIntelligence specifies: `baseUrl`, `apiKey`, `modelId`
- Supports `fastModelId` for performance optimization on simple reasoning steps
- `maxRetries` for LLM API call retry logic

Configuration is loaded by:
- **ConsoleGameConfigLoader** for console mode (reads from config file or defaults)
- GUI uses database-stored PlayerIntelligence records

### Console Mode (`lib/console/`)

Console-specific implementations:
- **ConsoleGameObserver** - Prints game events to terminal with color formatting
- **ConsoleGameUI** - Terminal UI utilities (spinners, colors, formatting)
- **ConsoleHumanPlayerDriverUI** - Interactive human player input in console
- **ConsoleGameConfigLoader** - Loads configuration for console games

### Flutter UI (`lib/page/`)

Pages follow MVVM pattern with GetIt dependency injection:
- **BootstrapPage** - Initial loading screen
- **HomePage** - Main menu
- **GamePage** - Active game UI
- **SettingsPage** - Configuration management
- **PlayerIntelligencePage** - Manage AI player configurations
- **DebugPage** - Development tools (currently set as initial route)

**Routing:**
- Uses **auto_route** package (`lib/router/router.dart`)
- Routes defined with `@AutoRouterConfig` annotation
- Run code generator after route changes

**State Management:**
- Uses **signals** package for reactive state
- ViewModels registered in `lib/di.dart` via GetIt

### Database (`lib/database/`)

- **Database** - SQLite database singleton using laconic package
- **PlayerIntelligenceRepository** - CRUD operations for AI configurations
- Migrations in `database/migration/`

## Key Patterns & Conventions

1. **Dependency Injection**: GetIt container initialized in `main.dart` via `DI.ensureInitialized()`

2. **Event-Driven**: Game state changes emit events through GameState's event stream, observers react to events

3. **Strategy Pattern**: PlayerDriver abstraction allows swapping AI/Human control

4. **Multi-Step Reasoning**: AIReasoningEngine chains multiple ReasoningStep implementations

5. **Observable Pattern**: GameObserver receives all game events for UI/logging

6. **Repository Pattern**: Database access through dedicated repository classes

## LLM Integration

The project uses **openai_dart** package to communicate with OpenAI-compatible APIs. Each AI player maintains its own OpenAIClient configured via PlayerIntelligence settings.

**Performance Optimization:**
- Two-tier model strategy: complex reasoning uses main model, simple tasks use `fastModelId`
- Fast model used for: Playbook selection, Mask selection, Self-reflection
- Main model used for: Fact analysis, Identity inference, Strategy planning, Speech generation

**Retry Logic:**
- AIPlayerDriver implements retry logic with exponential backoff
- Controlled by `maxRetries` in GameConfig

## Code Generation

This project uses several code generators. After modifying annotated files, run:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

Generators used:
- **auto_route_generator** - Routing code
- **json_serializable** - JSON serialization
- **flutter_gen_runner** - Asset references

## Important Notes

- **Chinese Language**: This project uses Chinese for game text, player interactions, and UI. All prompts to LLMs are in Chinese.

- **Role Knowledge**: Players only see information available to their role. InformationFilter enforces this.

- **Game Loop**: The `GameEngine.loop()` method is designed to be called repeatedly. It returns `false` when the game ends.

- **Resource Cleanup**: Always call `GameEngine.dispose()` after game completion to clean up event streams and prevent memory leaks.

- **Human Player Integration**: When creating a game with human players, ensure the HumanPlayerDriverInterface implementation is passed to the GameObserver so it can display prompts correctly.
