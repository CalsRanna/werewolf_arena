# 多模型配置指南

Werewolf Arena 现在支持为不同的玩家和角色配置不同的LLM模型，让您可以创建更丰富多样的游戏体验。

## 配置方法

### 1. 基本结构

在配置文件中，您可以使用以下三个部分来配置模型：

```yaml
# 默认LLM配置（当没有特定配置时使用）
llm:
  model: "deepseek/deepseek-chat-v3.1"
  api_key: "your-api-key"
  temperature: 0.7
  max_tokens: 1000
  timeout_seconds: 30
  max_retries: 3

# 角色特定的模型配置
role_models:
  "werewolf":
    model: "gpt-4o"
    api_key: "your-api-key"
    temperature: 0.9  # 更高的温度让狼人更激进
    max_tokens: 1500
  "seer":
    model: "claude-3-5-sonnet"
    api_key: "your-api-key"
    temperature: 0.5  # 更低的温度让预言家更理性
    max_tokens: 1200

# 玩家特定的模型配置
player_models:
  "1":
    model: "gpt-4o"
    api_key: "your-api-key"
    temperature: 0.8
    max_tokens: 1500
  "2":
    model: "claude-3-5-sonnet"
    api_key: "your-api-key"
    temperature: 0.6
    max_tokens: 1200
```

### 2. 配置优先级

系统按以下优先级选择模型配置：

1. **玩家特定配置** (`player_models`) - 最高优先级
2. **角色特定配置** (`role_models`) - 中等优先级
3. **默认配置** (`llm`) - 最低优先级

### 3. 配置参数说明

每个模型配置支持以下参数：

- `model`: 模型名称（如 "gpt-4o", "claude-3-5-sonnet"）
- `api_key`: API密钥
- `temperature`: 温度参数（0.0-1.0，控制创造性）
- `max_tokens`: 最大token数量
- `timeout_seconds`: 请求超时时间
- `max_retries`: 最大重试次数

## 使用示例

### 示例1：为不同角色配置不同模型

```yaml
role_models:
  "werewolf":
    model: "gpt-4o"
    api_key: "your-gpt-key"
    temperature: 0.9  # 激进的狼人
    max_tokens: 1500
  "seer":
    model: "claude-3-5-sonnet"
    api_key: "your-claude-key"
    temperature: 0.5  # 理性的预言家
    max_tokens: 1200
  "witch":
    model: "deepseek/deepseek-chat-v3.1"
    api_key: "your-deepseek-key"
    temperature: 0.7  # 平衡的女巫
    max_tokens: 1000
```

### 示例2：为特定玩家配置不同模型

```yaml
player_models:
  "1":
    model: "gpt-4o"
    api_key: "your-gpt-key"
    temperature: 0.8
    max_tokens: 1500
  "2":
    model: "claude-3-5-sonnet"
    api_key: "your-claude-key"
    temperature: 0.6
    max_tokens: 1200
```

### 示例3：混合配置

```yaml
# 默认使用DeepSeek
llm:
  model: "deepseek/deepseek-chat-v3.1"
  api_key: "your-deepseek-key"
  temperature: 0.7
  max_tokens: 1000

# 狼人使用GPT-4，更激进
role_models:
  "werewolf":
    model: "gpt-4o"
    api_key: "your-gpt-key"
    temperature: 0.9
    max_tokens: 1500

# 1号玩家特别配置（即使他是狼人，也会使用这个配置）
player_models:
  "1":
    model: "claude-3-5-sonnet"
    api_key: "your-claude-key"
    temperature: 0.5
    max_tokens: 1200
```

## 温度建议

不同角色建议使用不同的温度值：

- **狼人**: 0.8-0.9 - 更激进和有创造力
- **预言家**: 0.4-0.6 - 更理性和逻辑化
- **女巫**: 0.6-0.8 - 平衡的决策
- **守卫**: 0.5-0.7 - 保守的防御思维
- **村民**: 0.7-0.8 - 普通的村民思维

## 运行游戏

使用自定义配置文件运行游戏：

```bash
dart run bin/werewolf_arena.dart --config config/your_config.yaml
```

## 注意事项

1. 确保所有API密钥都有效
2. 不同的模型可能有不同的API格式和限制
3. 建议先用小规模游戏测试配置
4. 温度值过高可能导致不合理的游戏行为

## 完整示例配置

参考 `config/multi_model_example.yaml` 文件查看完整的配置示例。