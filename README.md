# RelayDog

RelayDog is a local macOS menu bar relay for AI clients. It exposes one local listener, routes OpenAI-compatible and Claude-compatible requests to configured upstream gateways, and keeps configuration and logs on your Mac.

RelayDog 是一个 macOS 菜单栏 AI 中转工具。它在本机提供固定客户端地址，把 OpenAI 兼容和 Claude 兼容请求路由到你配置的多个中转站，配置与日志都保存在本机。

## 中文说明

### 功能特性

- 单一本地监听地址：默认 `127.0.0.1:18787`
- OpenAI 兼容客户端地址：`http://127.0.0.1:18787/v1`
- Claude / Anthropic 客户端地址：`http://127.0.0.1:18787`
- 按请求路径和 Header 自动识别 OpenAI 兼容或 Claude 兼容协议
- 多中转站管理，支持启用 / 禁用、权重、超时、备注
- 每个中转站可分别配置 OpenAI 兼容和 Claude 兼容能力
- 支持模型列表、模型同步和模型名称映射
- 支持请求日志，便于排查客户端真实请求
- macOS 顶部菜单快捷操作：打开设置、复制客户端地址、切换路由、开启日志
- 设置页支持中文 / English / 跟随系统

### 快速启动

环境要求：

- macOS 13 或更高版本
- Xcode / Swift 工具链
- Swift Package Manager

启动菜单栏应用：

```bash
./dev.sh
```

启动后 Settings 窗口会自动弹出，同时 macOS 顶部菜单栏会显示 RelayDog 小图标。

只启动本地代理守护进程：

```bash
./dev.sh daemon
```

手动构建：

```bash
swift build --product RelayDogMenuBar
```

运行测试：

```bash
swift test
```

### 客户端配置

OpenAI 兼容客户端：

```text
Base URL: http://127.0.0.1:18787/v1
API Key: 任意占位值，真实 Key 由 RelayDog 的上游配置决定
```

Claude Code / Anthropic 兼容客户端：

```text
Base URL: http://127.0.0.1:18787
API Key: 任意占位值，真实 Key 由 RelayDog 的上游配置决定
```

### 使用流程

1. 执行 `./dev.sh`
2. 在 Settings 的 “连接” 页面添加中转站
3. 配置 OpenAI 兼容或 Claude 兼容能力
4. 填写上游 Base URL 和 API Key
5. 按需同步模型或手动填写模型
6. 如需模型别名，配置模型映射
7. 在 “概览” 页面或顶部菜单复制客户端地址
8. 在 Codex、Claude Code 或其他客户端中使用本机地址

### 本地数据

RelayDog 使用以下本机目录：

```text
~/.relaydog/
├── config.json
├── logs/
└── state.json
```

注意：

- `config.json` 会明文保存上游 API Key
- 请求日志默认关闭
- 开启请求日志后，日志可能包含 Header、Prompt、响应正文和 API Key 等敏感信息
- RelayDog 不上传配置、日志或请求数据

## English

### Features

- Single local listener: `127.0.0.1:18787` by default
- OpenAI-compatible client URL: `http://127.0.0.1:18787/v1`
- Claude / Anthropic-compatible client URL: `http://127.0.0.1:18787`
- Automatic protocol detection by request path and headers
- Multiple upstream gateways with enable toggles, weights, timeouts, and notes
- Per-upstream OpenAI-compatible and Claude-compatible capabilities
- Model lists, model sync, and model name mapping
- Request logs for local debugging
- macOS menu bar shortcuts for settings, client URL copy, route switching, and logs
- Chinese, English, and system language modes

### Quick Start

Requirements:

- macOS 13 or later
- Xcode / Swift toolchain
- Swift Package Manager

Run the menu bar app:

```bash
./dev.sh
```

RelayDog opens the Settings window on launch and keeps a small icon in the macOS menu bar.

Run only the local proxy daemon:

```bash
./dev.sh daemon
```

Build manually:

```bash
swift build --product RelayDogMenuBar
```

Run tests:

```bash
swift test
```

### Client Configuration

OpenAI-compatible clients:

```text
Base URL: http://127.0.0.1:18787/v1
API Key: any placeholder value; the real key is configured per upstream in RelayDog
```

Claude Code / Anthropic-compatible clients:

```text
Base URL: http://127.0.0.1:18787
API Key: any placeholder value; the real key is configured per upstream in RelayDog
```

### Typical Workflow

1. Run `./dev.sh`
2. Open the Connections tab in Settings
3. Add an upstream gateway
4. Configure OpenAI-compatible or Claude-compatible capability
5. Fill in the upstream Base URL and API Key
6. Sync models or enter model names manually
7. Add model mappings if the client model name should differ from the upstream model name
8. Copy the client URL from Overview or the menu bar
9. Use the local URL in Codex, Claude Code, or another compatible client

### Local Data

RelayDog stores local data under:

```text
~/.relaydog/
├── config.json
├── logs/
└── state.json
```

Security notes:

- `config.json` stores upstream API keys in plaintext
- Request logging is disabled by default
- When enabled, request logs may contain headers, prompts, response bodies, and API keys
- RelayDog does not upload your configuration, logs, or request data

## Development

Main targets:

- `RelayDogMenuBar`: macOS menu bar app
- `relaydogd`: local proxy daemon
- `RelayDogApp`: settings and menu UI
- `RelayDogCore`: proxy, routing, config, logging, and protocol logic

Useful commands:

```bash
./dev.sh
./dev.sh daemon
swift build --product RelayDogMenuBar
swift test
```

## Design Notes

See [RelayDog_Product_Design.md](RelayDog_Product_Design.md) for the product design, architecture, menus, settings pages, storage model, and security notes.
