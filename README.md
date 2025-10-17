# Werewolf Arena (狼人杀竞技场)

An AI-powered Werewolf (Mafia) game implementation built with Flutter and Dart. Watch AI players powered by Large Language Models (GPT, Claude, etc.) engage in strategic deception, deduction, and social gameplay.

[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/CalsRanna/werewolf_arena)
[![Flutter](https://img.shields.io/badge/Flutter-3.9+-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.9+-0175C2?logo=dart)](https://dart.dev)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## Features

- **AI-Powered Gameplay**: Players controlled by LLMs with advanced prompt engineering for strategic and tactical play
- **Dual Interface**: Beautiful Flutter GUI and fully functional CLI mode with colored output
- **Multiple Game Modes**: 9-player (2 wolves) and 12-player (4 wolves) configurations
- **Rich Role System**: 6 roles with unique abilities - Werewolf, Seer, Witch, Guard, Hunter, Villager
- **Event-Driven Architecture**: 16 event types with complete game history and replay capability
- **Skill-Based System**: 11 skills (discuss, kill, heal, poison, protect, investigate, shoot, speak, vote, etc.)
- **Flexible Configuration**: Per-player model customization via YAML (mix GPT-4, Claude, DeepSeek in one game)
- **Strategic AI**: Sophisticated AI behavior with role-playing, deception, logical reasoning, and tactical gameplay
- **Robust LLM Integration**: Retry mechanism, JSON parsing, multiple provider support (OpenAI, Anthropic, DeepSeek)

## Game Roles

### Evil Team (狼人阵营)
- **Werewolf (狼人)**: Collaborates with wolf teammates to kill one player each night

### Good Team (好人阵营)
- **Seer (预言家)**: Investigates one player's identity each night
- **Witch (女巫)**: Has one antidote (heal) and one poison (kill). Cannot heal herself
- **Guard (守卫)**: Protects one player from werewolf attacks each night. Cannot protect the same player consecutively
- **Hunter (猎人)**: When killed by werewolves or voted out, can shoot another player. Cannot shoot if poisoned by witch
- **Villager (平民)**: No special abilities, relies on deduction and persuasion

## Quick Start

### Prerequisites

- Flutter SDK 3.9 or higher
- Dart SDK 3.9 or higher
- API keys for LLM providers (OpenAI, Anthropic, etc.)

### Installation

```bash
# Clone the repository
git clone https://github.com/cals/werewolf_arena.git
cd werewolf_arena

# Install dependencies
flutter pub get

# Generate code (routes, assets)
dart run build_runner build --delete-conflicting-outputs
```

### Configuration

Create a `werewolf_config.yaml` file in the project root:

```yaml
# Default LLM configuration
default_llm:
  model: gpt-4o-mini
  api_key: ${OPENAI_API_KEY}  # Use environment variable
  base_url: https://api.openai.com/v1

# Override models for specific players (optional)
player_models:
  2:  # Player 2 uses Claude
    model: claude-3-5-sonnet-20241022
    api_key: ${ANTHROPIC_API_KEY}
    base_url: https://api.anthropic.com
  3:  # Player 3 uses DeepSeek
    model: deepseek-chat
    api_key: ${DEEPSEEK_API_KEY}
    base_url: https://api.deepseek.com
```

Set environment variables:

```bash
export OPENAI_API_KEY="your-openai-key"
export ANTHROPIC_API_KEY="your-anthropic-key"
export DEEPSEEK_API_KEY="your-deepseek-key"
```

### Running the Game

**GUI Mode (Flutter):**
```bash
flutter run
```

**CLI Mode (Console):**
```bash
# Run with default 9-player game
dart run bin/main.dart

# Run with custom configuration
dart run bin/main.dart -c werewolf_config.yaml

# Run with 12 players
dart run bin/main.dart -p 12
```

## Architecture

The project follows **Domain-Driven Design (DDD)** with clear separation of concerns:

### Core Layers

```
lib/
├── engine/              # Pure Dart game logic (no Flutter dependencies)
│   ├── domain/         # Entities (Player, Role), value objects, enums
│   ├── events/         # Event-driven game state changes (16 event types)
│   ├── skills/         # Skill system (11 skills: kill, heal, poison, protect, etc.)
│   ├── processors/     # Phase processors (night/day logic)
│   ├── drivers/        # Player drivers (AI via LLM, future human support)
│   └── scenarios/      # Game configurations (9-player, 12-player)
├── page/               # Flutter UI pages (home, game, settings, debug)
├── router/             # Auto-route navigation
├── console/            # CLI interface with colored output
└── services/           # Configuration and utilities
```

### Game Scenarios

**9-Player Standard (标准9人局)**
- 2 Werewolves + 3 Villagers + Seer + Witch + Guard + Hunter
- Balanced configuration for quick games

**12-Player Standard (标准12人局)**
- 4 Werewolves + 4 Villagers + Seer + Witch + Guard + Hunter
- Extended gameplay with more strategic depth

### Key Design Patterns

**Event-Driven Game Flow**
- All actions produce `GameEvent` objects (16 types: DeadEvent, SpeakEvent, VoteEvent, WerewolfKillEvent, etc.)
- Events stored in immutable history with visibility rules (public/private/role-specific)
- Real-time event streaming via `GameState.eventStream` for observers
- Events support narrative conversion for AI context

**Skill System**
- Every player action is a `GameSkill` (WerewolfDiscussSkill, KillSkill, HealSkill, ProtectSkill, etc.)
- Skills generate contextual LLM prompts with game state, event history, and role knowledge
- Structured JSON responses for target selection and reasoning
- Skills are composable - each role defines its skill set

**Phase Processors**
- `NightPhaseProcessor` (lib/engine/processors/night_phase_processor.dart:42-70): Sequential night actions with delays
- `DayPhaseProcessor` (lib/engine/processors/day_phase_processor.dart:23-98): Speech and voting phases
- Each processor implements `GameProcessor` interface
- Processors handle event emission and state transitions

**Player Driver Abstraction**
- `AIPlayerDriver` (lib/engine/drivers/ai_player_driver.dart): LLM-powered strategic decision making
- Advanced prompt engineering for role-playing and tactical gameplay
- Retry logic with exponential backoff for API reliability
- JSON response cleaning for parsing robustness
- Future: `HumanPlayerDriver` for human player support

**LLM Integration**
- Supports OpenAI-compatible APIs (OpenAI, Anthropic, DeepSeek, etc.)
- Configurable per-player models via YAML
- Built-in retry mechanism (3 attempts with exponential backoff)
- Detailed context construction with game state, events, and role prompts

## Game Flow

### Night Phase (夜晚阶段)
1. **Werewolf Discussion** - Werewolves discuss strategy and select kill target
2. **Werewolf Kill** - Werewolves vote to kill a player
3. **Seer Investigation** - Seer investigates one player's identity
4. **Witch Heal** - Witch can use antidote to save the killed player (cannot save herself)
5. **Witch Poison** - Witch can poison a player (cannot use both heal and poison in same night)
6. **Guard Protection** - Guard protects a player (cannot protect same player consecutively)
7. **Night Settlement** - Deaths are calculated based on kills, heals, poisons, and protection

### Day Phase (白天阶段)
1. **Death Announcement** - Judge announces who died last night
2. **Player Speeches** - All alive players speak in order to share analysis and suspicions
3. **Voting** - Players vote simultaneously to execute a suspect
4. **Execution** - Player with most votes is eliminated
5. **Hunter Revenge** - If hunter is killed, can shoot another player (if not poisoned)

### Win Conditions (胜利条件)
- **Good Wins**: All werewolves are eliminated
- **Evil Wins**: Werewolf count ≥ Good player count

## Development

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

### Adding a New Role

1. Create role class extending `GameRole` in `lib/engine/domain/entities/`
   ```dart
   class MyRole extends GameRole {
     @override
     String get id => 'my_role';

     @override
     String get name => '角色名';

     @override
     String get prompt => '角色提示词...';

     @override
     List<GameSkill> get skills => [SpeakSkill(), VoteSkill()];
   }
   ```
2. Register in `GameRoleFactory.createRole()`
3. Add to `RoleType` enum in `lib/engine/domain/enums/role_type.dart`
4. Include in scenario's `roleDistribution` map

### Adding a New Skill

1. Create skill class extending `GameSkill` in `lib/engine/skills/`
   ```dart
   class MySkill extends GameSkill {
     @override
     String get prompt => 'AI决策提示...';

     @override
     String formatPrompt(GameState state, GamePlayer player) {
       // 构建包含游戏状态的完整提示
       return '...';
     }
   }
   ```
2. Add to role's `skills` getter
3. Implement skill execution in phase processor via `player.cast(skill, state)`

### Understanding AI Decision Making

The AI system (lib/engine/drivers/ai_player_driver.dart:22-39) uses a sophisticated prompt that:
- Makes AI forget it's an AI and fully roleplay as a player
- Emphasizes strategic thinking, psychological tactics, and narrative building
- Encourages advanced strategies (deception, alliances, tactical voting)
- Maintains memory and consistency across game rounds

## Technology Stack

- **Framework**: Flutter 3.9+
- **Language**: Dart 3.9+
- **State Management**: Signals
- **Dependency Injection**: GetIt
- **Routing**: Auto Route
- **LLM Integration**: OpenAI Dart SDK
- **Configuration**: YAML
- **Logging**: Logger package

## Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Commit Convention

- `feat:` New features
- `fix:` Bug fixes
- `refactor:` Code refactoring
- `docs:` Documentation updates
- `test:` Test additions or modifications

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Inspired by the classic Werewolf/Mafia social deduction game
- Built with Flutter and Dart
- AI powered by OpenAI, Anthropic, and other LLM providers

## Contact

- Repository: [https://github.com/cals/werewolf_arena](https://github.com/cals/werewolf_arena)
- Issues: [https://github.com/cals/werewolf_arena/issues](https://github.com/cals/werewolf_arena/issues)

---

Made with love by the Werewolf Arena team
