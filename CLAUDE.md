# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Werewolf Arena (狼人杀竞技场) is an AI-powered Werewolf game implementation in Flutter/Dart. The game features AI players that use LLMs (GPT, Claude, etc.) to make strategic decisions, supporting both GUI (Flutter) and CLI modes.

## Development Commands

### Setup and Dependencies
```bash
# Install dependencies
flutter pub get

# Run code generation for routes and assets
dart run build_runner build --delete-conflicting-outputs
```

### Running the Application
```bash
# Run Flutter GUI app (development)
flutter run

# Run CLI/console mode
dart run bin/main.dart

# Run with specific configuration
dart run bin/main.dart -c werewolf_config.yaml

# Run with 9 or 12 players
dart run bin/main.dart -p 12
```

### Code Quality
```bash
# Analyze code
flutter analyze
dart analyze

# Run tests
flutter test
dart test

# Format code
dart format .
```

## Architecture Overview

### Core Architecture Pattern

The project follows a **Domain-Driven Design (DDD)** with clear separation:

1. **Engine Layer** (`lib/engine/`) - Pure Dart game logic, no Flutter dependencies
   - `domain/` - Core entities, value objects, enums (Player, Role, Skills)
   - `events/` - Event-driven game state changes
   - `skills/` - Skill system (each role ability is a skill)
   - `processors/` - Phase processors (night/day logic)
   - `drivers/` - Player drivers (AI/Human input abstraction)
   - `scenarios/` - Game scenarios (9-player, 12-player configurations)

2. **UI Layer** (`lib/page/`, `lib/router/`) - Flutter-specific code
   - Uses `auto_route` for navigation
   - `signals` for reactive state management
   - ViewModels follow factory pattern via GetIt DI

3. **Console Layer** (`lib/console/`, `bin/main.dart`) - CLI interface
   - Fully functional terminal-based game
   - ColoredConsole output
   - ConsoleGameObserver for event handling

### Key Design Patterns

**Event-Driven Game Flow**
- All game actions produce `GameEvent` objects
- Events are stored in `GameState.events` history
- Observers can listen to events via `GameState.eventStream`
- Events include: SpeakEvent, VoteEvent, DeadEvent, WerewolfKillEvent, etc.

**Skill System**
- Every player action is a `GameSkill` (speak, vote, kill, heal, protect, etc.)
- Skills have `formatPrompt()` to generate LLM prompts
- Skills return `SkillResult` with target and reasoning
- Example: `WerewolfDiscussSkill`, `KillSkill`, `HealSkill`, `VoteSkill`

**Phase Processors**
- `NightPhaseProcessor` - handles werewolf kills, seer investigations, witch actions, guard protection
- `DayPhaseProcessor` - handles player speeches, voting, executions, last words
- Each processor implements `GameProcessor` interface

**Player Driver Abstraction**
- `PlayerDriver` interface separates decision-making from game logic
- `AIPlayerDriver` uses LLM APIs (OpenAI/Anthropic) for AI decisions
- `HumanPlayerDriver` for future human player support
- Drivers receive game context and return formatted responses

### Game Flow

1. **Initialization**
   - `GameEngine` created with config, scenario, players, observer
   - `GameState` initialized with player list
   - Game starts in night phase, day 1

2. **Game Loop** (`GameEngine.loop()`)
   - Select processor based on current phase
   - Processor executes all phase actions via skill system
   - Check win conditions after each phase
   - Transition to next phase

3. **Phase Execution**
   - Night: Werewolf discussion → kill → seer investigate → witch heal/poison → guard protect
   - Day: Announce deaths → last words → speeches → voting → execute

4. **Win Conditions** (checked in `GameState.checkGameEnd()`)
   - Good guys win: All werewolves dead
   - Werewolves win: All gods dead OR all villagers dead (with numerical advantage)

### Configuration System

**Game Configuration** (`werewolf_config.yaml`)
- `default_llm`: Default LLM settings (model, API key, base URL)
- `player_models`: Per-player model overrides (e.g., player 2 uses Claude, player 3 uses GPT-4)
- Environment variable substitution supported: `${OPENAI_API_KEY}`

**Player Intelligence** (`PlayerIntelligence`)
- Each AI player has: `modelId`, `apiKey`, `baseUrl`
- Supports OpenAI-compatible APIs (OpenAI, Anthropic, DeepSeek, etc.)

### Dependency Injection

Uses GetIt with two registration patterns:
- **Singleton**: `ConfigService` (lazy singleton)
- **Factory**: All ViewModels (fresh instance per use)

Initialize in app startup: `DI.ensureInitialized()`

### State Management

**Engine State** (Pure Dart)
- `GameState` holds all game data (players, events, phase, day number)
- Immutable value objects for game concepts
- Stream-based event propagation

**UI State** (Flutter)
- `signals` package for reactive state
- Computed signals for derived values (alive players count, formatted time, etc.)
- ViewModel pattern for each page

## Important Files and Locations

### Entry Points
- `lib/main.dart` - Flutter GUI app entry
- `bin/main.dart` - CLI console app entry

### Core Game Logic
- `lib/engine/game_engine.dart` - Main game loop orchestrator
- `lib/engine/game_state.dart` - Game state management and win condition logic
- `lib/engine/processors/night_phase_processor.dart:42-110` - Night phase sequence
- `lib/engine/processors/day_phase_processor.dart` - Day phase sequence

### AI System
- `lib/engine/drivers/ai_player_driver.dart:21-38` - Core AI player prompt
- `lib/engine/drivers/llm_service.dart` - LLM API integration with retry logic
- `lib/engine/skills/werewolf_discuss_skill.dart` - Example of complex skill with detailed prompt

### Role System
- `lib/engine/domain/entities/game_role.dart` - Role interface
- `lib/engine/domain/entities/werewolf_role.dart`, `witch_role.dart`, etc. - Specific roles
- `lib/engine/domain/entities/game_role_factory.dart` - Role factory

### Configuration Loading
- `lib/console/console_config_loader.dart` - Console config loader
- `lib/services/config_service.dart` - Flutter config service (with shared_preferences)
- `werewolf_config.yaml` - Game configuration template

## Code Generation

The project uses build_runner for:
1. **Auto Route** - Router code generation (router.gr.dart)
2. **JSON Serializable** - Model serialization (if used)
3. **Flutter Gen** - Asset code generation (assets.gen.dart)

After modifying routes or assets, run:
```bash
dart run build_runner build --delete-conflicting-outputs
```

## Testing Strategy

- Unit tests focus on game logic in `lib/engine/`
- Keep UI tests minimal (Flutter is framework, engine is core)
- Mock LLM responses using `mocktail` for AI driver tests
- Test win conditions thoroughly in `GameState.checkGameEnd()`

## Common Patterns

### Adding a New Role
1. Create role class extending `GameRole` in `lib/engine/domain/entities/`
2. Define role's skills in `skills` getter
3. Add role-specific prompt in `prompt` getter
4. Register in `GameRoleFactory`
5. Add to scenario's role distribution

### Adding a New Skill
1. Create skill class extending `GameSkill` in `lib/engine/skills/`
2. Implement `formatPrompt()` with detailed instructions for AI
3. Add skill to appropriate role's `skills` list
4. Use skill in phase processor via `player.cast(skill, state)`

### Modifying Game Flow
1. Edit phase processors (`night_phase_processor.dart`, `day_phase_processor.dart`)
2. Follow existing pattern: create event → emit event → handle in game state
3. Update win conditions if needed in `GameState._checkWinner()`

### Working with Events
- All events extend `GameEvent` base class
- Events have `type`, `timestamp`, `visibility` (public/private/role-specific)
- Create event → `state.handleEvent(event)` → appears in event log
- Observer pattern: listen to `state.eventStream` for real-time updates

## Special Considerations

### LLM Prompt Engineering
- Player prompts emphasize role-playing and strategic thinking (see `ai_player_driver.dart:21-38`)
- Each skill provides detailed context: game state, event history, role knowledge
- Responses are JSON-formatted for parsing (target selection, reasoning, speech)

### Platform Differences
- Engine code is platform-agnostic (pure Dart)
- Console mode uses `dart:io` (not available on web)
- Flutter UI uses platform channels for desktop features (window_manager, tray_manager)

### Performance
- Game loop has 500ms delays between steps for readability
- LLM calls can be slow (1-5 seconds per decision)
- Event history grows over time - consider cleanup for very long games

### Logging
- Use `GameEngineLogger.instance` for engine logs
- Use `LoggerUtil.instance` for app-level logs
- Console mode shows colored output via `ConsoleGameOutput`

## Git Workflow

Main branch: `main`
- Recent work focused on fixing night phase processing and AI discussion skills
- Bug fixes use `fix:` prefix, features use `feat:` prefix in commits
