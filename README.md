# 🐺 Werewolf Arena

An LLM-powered AI Werewolf (Mafia) battle platform where AI agents compete against each other in the classic social deduction game.

[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/CalsRanna/werewolf_arena)
[![Flutter](https://img.shields.io/badge/Flutter-3.9.0+-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.9.0+-0175C2?logo=dart)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## ✨ Features

### 🤖 Advanced AI Reasoning System

Each AI player is equipped with a complete cognitive reasoning chain:

- **Fact Analysis** - Extract key information from game events
- **Identity Inference** - Deduce other players' identities based on behavior patterns
- **Strategy Planning** - Formulate action plans aligned with role objectives
- **Tactical Playbooks** - Execute predefined complex tactics (fake-claiming, hook, deep-water)
- **Role Masks** - Adopt different speaking styles and personality disguises
- **Speech Generation** - Generate natural language that matches role identity and strategy
- **Self-Reflection** - Evaluate and adjust strategic performance

### 🎭 Rich Tactical System

**Tactical Playbook System**:
- Werewolf Fake-Claiming Seer: Seize discourse power, mislead good players
- Hook Tactics: Gain trust, betray in final rounds
- Guard Protection Strategy: Priority judgment and knife prediction
- Witch Potion Timing: Optimal timing for antidote and poison usage

**Role Mask System**:
- Aggressive Attacker, Calm Analyst, Confused Novice
- Peacemaker, Victimized Good Person, Authoritative Leader
- Follower, Scapegoat, Instigator

### 🧠 Social Network & Memory

- **Working Memory**: Store observations, inferences, and relationship data
- **Social Network Graph**: Track trust/suspicion relationships between players
- **Information Filter**: Filter visible information based on role permissions
- **Relationship Analysis**: Dynamically assess social dynamics between players

### 🎮 Dual-Mode Support

- **Console Mode**: Fast battles, support human player participation or god-mode spectating
- **GUI Mode**: Beautiful Flutter cross-platform interface (in development)

## 🚀 Quick Start

### Requirements

- **Dart SDK**: 3.9.0+
- **Flutter**: 3.9.0+ (required for GUI mode)
- **LLM API**: OpenAI-compatible API (OpenAI, DeepSeek, Qwen, etc.)

### Installation

```bash
# Clone repository
git clone https://github.com/cals/werewolf_arena.git
cd werewolf_arena

# Install dependencies
flutter pub get
```

### Configure LLM API

Create `werewolf_config.yaml` in project root:

```yaml
# Default LLM configuration
default_llm:
  api_key: sk-xxxxxxxxxxxx
  base_url: "https://api.openai.com/v1"
  max_retries: 10

# Fast model (for simple tasks, optional)
# Recommended: gpt-4o-mini, claude-3-5-haiku-20241022, deepseek-chat
fast_model_id: gpt-4o-mini

# Player model configuration (12 players cycle through)
player_models:
  - gpt-4o
  - claude-3-7-sonnet-20250219
  - deepseek/deepseek-v3.2-exp
```

### Run the Game

**Console Mode**:

```bash
# God mode spectating (recommended for first experience)
dart run bin/main.dart -g

# Play as specific player
dart run bin/main.dart --player 1

# Random player assignment
dart run bin/main.dart

# Enable debug logging
dart run bin/main.dart -g -d
```

**Flutter GUI Mode**:

```bash
flutter run
```

## 🎲 Game Rules

### Standard 12-Player Setup

- **Factions**: 4 Werewolves vs 4 Villagers + 4 Gods
- **Roles**:
  - 🐺 **Werewolf**: Kill players at night, werewolves know each other
  - 👤 **Villager**: No special abilities, rely on deduction to find werewolves
  - 🔮 **Seer**: Check one player's identity each night
  - 💊 **Witch**: Has one antidote and one poison
  - 🛡️ **Guard**: Protect one player each night (cannot protect same player consecutively)
  - 🔫 **Hunter**: Can shoot one player when eliminated

### Victory Conditions (Edge Slaughter Rules)

- **Good Team Victory**: All werewolves eliminated
- **Werewolf Victory**: Eliminate all villagers OR eliminate all god roles

### Game Flow

```
Night Phase → Day Discussion → Vote Exile → Check Victory
   ↑                                           ↓
   └───────────────────────────────────────────┘
```

**Night Phase**:
1. Guard protects a player
2. Werewolves discuss and kill target
3. Seer checks identity
4. Witch decides whether to use potions

**Day Phase**:
1. Announce night death results
2. Players speak and discuss in order
3. Everyone votes to exile a player
4. Check victory conditions

## 🏗️ Technical Architecture

### Core Modules

```
lib/engine/              # Game engine core
├── game_engine.dart     # Game main loop controller
├── game_state.dart      # Game state management
├── game_config.dart     # Configuration management
├── player/              # Player system
│   ├── ai_player.dart   # AI player
│   └── human_player.dart # Human player
├── driver/              # Decision drivers
│   ├── ai_player_driver.dart      # AI decision engine
│   └── human_player_driver.dart   # Human interaction
├── reasoning/           # AI reasoning system
│   ├── ai_reasoning_engine.dart   # Reasoning engine
│   └── steps/           # 7-step reasoning chain
├── playbook/            # Tactical playbook library
├── mask/                # Role mask library
├── memory/              # Memory & social network
├── role/                # Role definitions
├── skill/               # Skill system
└── event/               # Event system
```

### AI Reasoning Flow

```mermaid
graph LR
    A[Game Events] --> B[Fact Analysis]
    B --> C[Identity Inference]
    C --> D[Strategy Planning]
    D --> E[Playbook Selection]
    E --> F[Mask Selection]
    F --> G[Speech Generation]
    G --> H[Execute Action]
    H --> I[Self Reflection]
```

### Dual-Model Architecture

For balancing performance and quality:

- **Main Model** (complex reasoning): Fact analysis, identity inference, strategy planning, speech generation
- **Fast Model** (simple tasks): Playbook selection, mask selection, self-reflection

This design significantly reduces API call costs and response latency.

## 🎯 Usage Examples

### Example 1: God Mode Spectating AI Battles

```bash
dart run bin/main.dart -g
```

You will see:
- Complete game flow
- All players' true identities
- AI reasoning processes and decisions
- Secret actions during night phase

### Example 2: Playing as Seer

```bash
dart run bin/main.dart --player 1
```

The game will assign you a role, and you will:
- Use role abilities at night
- Speak and discuss during the day
- Participate in voting
- Compete with AI players

### Example 3: Using Different Model Configurations

Edit `werewolf_config.yaml`:

```yaml
player_models:
  - gpt-4o                 # Players 1-4
  - claude-3-7-sonnet      # Players 5-8
  - deepseek/deepseek-chat # Players 9-12
```

This allows testing strategic performance of different models.

## 🛠️ Development Guide

### Project Structure

- `lib/` - Main codebase
  - `engine/` - Game engine core
  - `console/` - Console UI
  - `page/` - Flutter pages (GUI)
  - `database/` - Data persistence
  - `router/` - Route management
- `bin/` - Console application entry
- `asset/` - Resource files
- `test/` - Test files

### Running Tests

```bash
flutter test
```

### Code Generation

The project uses code generators. After modifying related files, run:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Code Linting

```bash
flutter analyze
```

## 📊 Performance Optimization Tips

1. **Use Fast Model**: Configure `fast_model_id` in `werewolf_config.yaml`
2. **Adjust Retry Count**: Set `max_retries` based on network conditions
3. **Concurrency Control**: Game engine automatically manages API call concurrency
4. **Cache Optimization**: Reasoning results are cached within rounds

## 🤝 Contributing

Contributions, suggestions, and issue reports are welcome!

1. Fork this repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add some amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Create Pull Request

## 📝 Tech Stack

- **Language**: Dart 3.9.0+
- **Framework**: Flutter 3.9.0+
- **LLM Integration**: openai_dart
- **Dependency Injection**: get_it
- **State Management**: signals
- **Routing**: auto_route
- **Database**: laconic (SQLite)
- **UI Components**: Lottie animations, Google Fonts

## 🔮 Roadmap

- [x] Core game engine
- [x] 7-step AI reasoning chain
- [x] Tactical playbook system
- [x] Role mask system
- [x] Console mode
- [ ] Complete Flutter GUI
- [ ] Multi-scenario support (9-player, city slaughter, etc.)
- [ ] Game replay feature
- [ ] AI battle leaderboard
- [ ] Custom role configuration
- [ ] Multi-language support

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Thanks to all LLM providers for making this project possible
- Thanks to the Flutter and Dart community for excellent tools and libraries
- Thanks to the Werewolf game for the inspiration

## 📮 Contact

- **Project Home**: https://github.com/cals/werewolf_arena
- **Issue Tracker**: [Issues](https://github.com/cals/werewolf_arena/issues)

<div align="center">

**If this project helps you, please give it a ⭐️ Star!**

Made with ❤️ by CalsRanna

</div>
