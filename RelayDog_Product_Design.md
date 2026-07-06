# RelayDog 产品设计方案（macOS）

## 产品定位

RelayDog 是一个 macOS 菜单栏 AI 中转工具。它在本机提供固定客户端地址，统一承接 OpenAI 兼容协议和 Claude / Anthropic 协议请求，并把请求路由到用户配置的多个上游中转站。

**RelayDog 默认透明转发，不做跨协议转换。**

除用户显式配置的 Header 覆盖、模型名称映射和请求日志外，RelayDog 不改写请求与响应。

设计原则：

- OpenAI 兼容协议请求只进入 OpenAI 兼容上游池
- Claude / Anthropic 协议请求只进入 Claude 兼容上游池
- 两套协议独立路由，互不 fallback
- 模型名称映射只在同协议内改写请求 JSON 的顶层 `model` 字段
- 一个中转站可以同时启用 OpenAI 兼容和 Claude 兼容能力
- 本地单端口按请求路径和 Header 自动识别协议
- 配置、状态和日志全部保存在本机用户目录 `~/.relaydog`

## 核心目标

用户只需要在客户端配置一次本机地址：

```text
OpenAI Base URL: http://127.0.0.1:18787/v1
Claude Base URL: http://127.0.0.1:18787
```

之后无需修改 Codex、Claude Code 或其他客户端配置，只在 RelayDog 中切换中转站和路由。

典型场景：

- Codex 请求 `http://127.0.0.1:18787/v1/responses`
- RelayDog 识别为 OpenAI 兼容请求
- RelayDog 按当前 OpenAI 路由选择上游
- 如配置了模型映射，把客户端模型名 `gpt-5.5` 改写为上游真实模型名 `glm5.2`
- 其余请求内容和响应内容透明转发

Claude Code 请求 `http://127.0.0.1:18787/v1/messages` 时，RelayDog 会识别为 Claude / Anthropic 请求，并只选择启用了 Claude 兼容能力的中转站。

## 架构

```text
macOS Menu Bar App
├── Settings Window
│   ├── Overview
│   ├── Connections
│   ├── Logs
│   ├── System
│   └── About
├── Status Item Menu
│   ├── Status and listener summary
│   ├── Copy client URLs
│   ├── Route switching
│   └── Request log shortcuts
├── Local Proxy Listener
│   └── 127.0.0.1:18787
│       ├── Protocol Detector
│       ├── OpenAI Router
│       │   ├── Model Mapping
│       │   ├── Request Logger
│       │   └── OpenAI-compatible Upstreams
│       └── Claude Router
│           ├── Request Logger
│           └── Claude-compatible Upstreams
└── Local Storage
    └── ~/.relaydog
```

本地只监听一个端口。OpenAI Router 与 Claude Router 在内部完全独立，请求识别后只进入对应协议池。

## 启动体验

RelayDog 是菜单栏应用，但启动时会自动打开设置窗口，避免用户只看到顶部菜单图标而误以为程序没有运行。

启动行为：

1. 初始化本机配置和运行目录
2. 启动本地监听器
3. 在 macOS 顶部菜单栏显示应用小图标
4. 自动弹出 Settings 窗口

用户关闭 Settings 窗口后，RelayDog 继续在菜单栏后台运行。再次点击顶部菜单图标可以打开快捷菜单。

## 协议支持

### 单端口协议识别

RelayDog 默认监听：

```text
http://127.0.0.1:18787
```

协议识别规则：

- OpenAI 兼容路径：`/v1/chat/completions`、`/v1/responses`、`/v1/completions`、`/v1/embeddings`、`/v1/images`、`/v1/audio` 等
- Claude / Anthropic 路径：`/v1/messages`、`/v1/complete` 等
- Header 辅助识别：`anthropic-version`、`anthropic-beta`、`x-api-key` 倾向 Claude；`Authorization: Bearer ...` 倾向 OpenAI
- 路径优先，Header 兜底
- 仍无法判断时返回明确错误，不随机转发

识别结果只决定进入哪个内部路由池，不做协议转换。

### OpenAI 兼容路由

- 默认原样转发 HTTP Body
- 原样转发 SSE
- 可覆盖 Authorization Header
- 可选模型名称映射
- 支持 Codex 和 OpenAI 兼容 SDK

### Claude 兼容路由

- 默认原样转发 Claude / Anthropic API
- 原样转发 SSE
- 不修改消息结构
- 可覆盖 `x-api-key` Header
- 支持 Claude Code

## 中转站管理

RelayDog 使用统一的中转站列表。每个中转站可以开启一个或多个协议能力：

- OpenAI 兼容
- Claude 兼容

每个中转站字段：

- 名称
- 启用状态
- 权重
- 超时
- 备注

每个协议能力字段：

- Base URL
- API Key
- Header 覆盖
- 健康检查路径
- 模型同步方式
- 模型列表
- 模型映射关系

当前界面策略：

- 中转站启用状态放在连接页列表中直接切换
- 添加 / 编辑弹窗不再重复显示中转站启用开关
- 协议类型由配置的协议能力判断，不再单独显示 “OpenAI 协议” 字段
- 协议标签使用 “OpenAI兼容” 和 “Claude兼容”
- 所有删除操作都需要确认

示例配置：

```json
{
  "listener": {
    "host": "127.0.0.1",
    "port": 18787,
    "enabled": true
  },
  "upstreams": [
    {
      "id": "glm",
      "name": "GLM Gateway",
      "enabled": true,
      "weight": 100,
      "timeoutSeconds": 60,
      "note": "",
      "protocols": {
        "openai": {
          "enabled": true,
          "baseURL": "https://example.com/openai/v1",
          "apiKey": "sk-plain-text",
          "headerOverrides": {},
          "healthCheckPath": "/v1/models",
          "modelSync": "manual",
          "models": ["glm5.2"],
          "modelMappings": {
            "gpt-5.5": "glm5.2"
          }
        }
      }
    }
  ],
  "routing": {
    "openai": {
      "mode": "roundRobin",
      "selectedUpstreamID": null
    }
  },
  "globalModelMappings": {},
  "requestLogging": {
    "enabled": false,
    "maxFileBytes": 52428800,
    "retentionDays": 7,
    "recordResponseBody": true
  },
  "language": "system"
}
```

## 模型名称映射

模型映射用于把客户端请求的模型名包装成上游真实模型名。

示例：

```json
{
  "modelMappings": {
    "gpt-5.5": "glm5.2"
  }
}
```

规则：

- 只匹配完整模型名
- 只改写请求体顶层 `model` 字段
- 未命中映射时原样转发
- 不改写消息、工具调用、图片、文件、stream 参数等字段
- 只在同协议内生效
- 不把 OpenAI 请求转换成 Claude 请求，也不把 Claude 请求转换成 OpenAI 请求

## 路由模式

配置层支持以下路由模式：

- 单一模式
- 轮询
- 加权轮询
- Failover
- 最低延迟优先

路由选择只在当前请求识别出的协议池内进行。例如 Codex 请求被识别为 OpenAI 兼容协议后，只会在启用了 OpenAI 兼容能力的中转站中选择。

当前菜单和概览页主要暴露“自动”和“固定中转站”两类日常选择。更细粒度策略保留在配置层和后续高级设置中扩展。

## 菜单栏

菜单栏只显示小图标，不显示品牌文字，避免占用顶部菜单空间。小图标使用项目 Logo 的圆角版本，并去除边缘白边。

点击小图标后显示快捷菜单：

```text
RelayDog Running
Local Listener: 127.0.0.1:18787

Open Settings
Copy OpenAI Base URL
Copy Claude Base URL

OpenAI Route: Auto >
Claude Route: Dual Gateway >

Request Logs: Off >
Reveal Log Folder

Quit RelayDog
```

中文界面对应：

```text
RelayDog 正在运行
本机监听: 127.0.0.1:18787

打开设置
复制 OpenAI 地址
复制 Claude 地址

OpenAI 路由: 自动 >
Claude 路由: Dual Gateway >

请求日志: 关闭 >
显示日志文件夹

退出 RelayDog
```

菜单设计原则：

- 顶部先说明程序正在运行和监听地址
- “打开设置”放在最高频操作区
- 复制客户端地址放在菜单里，降低首次配置成本
- 路由切换保留为子菜单
- 请求日志只保留开关和日志目录，不再提供独立 Viewer 入口
- 不放暂停代理按钮，避免误触导致客户端请求失败
- 不放新增中转站、模型同步、健康统计等低频配置入口

## 设置窗口

Settings 是主要配置中心，使用顶部选项卡组织。

```text
Settings
├── 概览 / Overview
├── 连接 / Connections
├── 日志 / Logs
├── 系统 / System
└── 关于 / About
```

### 概览 / Overview

用于快速复制客户端地址和确认路由。

- 客户端地址
  - OpenAI Base URL：`http://127.0.0.1:18787/v1`
  - Claude Base URL：`http://127.0.0.1:18787`
- 路由
  - 当前 OpenAI 路由
  - 当前 Claude 路由
  - 每个协议池的可用中转站

说明：

- 不再显示 “本机统一地址”
- 不再显示 OpenAI / Claude 统计卡片
- 不再显示本机数据板块

### 连接 / Connections

管理中转站列表和协议能力。

- 新增 / 编辑 / 删除中转站
- 在列表中直接启用 / 禁用中转站
- 配置权重、超时、备注
- 配置 OpenAI 兼容能力
- 配置 Claude 兼容能力
- 同步或手动维护模型列表
- 配置模型映射
- 在弹窗内测试中转站

测试中转站页面采用偏终端风格的深色请求 / 响应区域，便于查看原始调试内容。

### 日志 / Logs

管理请求日志。

- 开启 / 关闭请求日志
- 配置最大文件大小
- 配置日志保留天数
- 配置是否记录响应 Body
- 打开日志文件夹

健康与统计板块已从日志页移除。

### 系统 / System

管理应用级设置。

- 界面语言：跟随系统 / 中文 / English
- 本地监听 Host
- 本地监听 Port
- 本地监听启用状态
- 数据目录
- 配置文件
- 状态文件

### 关于 / About

展示项目介绍、能力摘要、存储说明和项目链接。

内容包括：

- 项目描述
- 单一本地端点
- OpenAI 与 Claude 路由
- 按中转站配置模型和映射
- 请求日志与调试测试
- 本地明文存储提醒
- GitHub 链接

## 状态定义

- `Running` / `正在运行`：本地监听正常，并且启用的协议有可用中转站
- `Degraded` / `异常`：应用仍在运行，但某个启用协议没有可用中转站、健康检查失败或最近请求失败
- `Offline` / `离线`：本地监听关闭、未运行或端口绑定失败

状态会显示在顶部菜单的第一行。

## 常用工作流

### 首次配置

1. 执行 `./dev.sh` 启动菜单栏应用
2. Settings 自动弹出
3. 进入 “连接 / Connections”
4. 添加中转站
5. 配置 OpenAI 兼容或 Claude 兼容能力
6. 填写 Base URL 与 API Key
7. 同步模型或手动填写模型
8. 如需包装客户端模型名，添加模型映射
9. 回到 “概览 / Overview” 或顶部菜单复制客户端地址
10. 把地址填入 Codex、Claude Code 或其他客户端

### 日常切换

1. 点击 macOS 顶部菜单栏小图标
2. 在 `OpenAI Route` 子菜单切换 OpenAI 兼容请求的中转站
3. 在 `Claude Route` 子菜单切换 Claude 请求的中转站
4. 选择 `Auto` 时按当前路由配置自动选择

### 调试请求

1. 点击顶部菜单小图标
2. 在 `Request Logs` 中开启请求日志
3. 重新发起 Codex 或 Claude Code 请求
4. 点击 `Reveal Log Folder` 打开日志目录
5. 查看 JSON Lines 日志中的 Header、Body、模型映射、上游响应和错误
6. 调试完成后关闭请求日志

## 本地数据目录

RelayDog 启动时在用户目录下创建：

```text
~/.relaydog/
├── config.json
├── logs/
│   ├── request-current.jsonl
│   ├── request-2026-07-04-001.jsonl.gz
│   └── ...
└── state.json
```

`config.json` 明文保存：

- 本地监听配置
- 中转站配置
- OpenAI / Claude 协议能力配置
- API Key
- 路由模式
- 模型列表
- 模型名称映射
- 请求日志设置
- 界面语言

`state.json` 保存运行状态缓存，例如最近选择的节点、健康检查结果、统计快照等。

## 请求日志

请求日志默认关闭。开启后，RelayDog 会记录真实请求数据，便于本机排查客户端实际发送了什么。

记录内容：

- 时间
- 协议类型
- 请求方法与路径
- 选中的上游节点
- 上游 URL
- 请求 Header
- 请求 Body
- 模型映射前后的模型名
- 响应状态码
- 响应 Header
- 响应 Body 或 SSE 原始事件流
- 耗时
- 错误信息

日志格式：

- JSON Lines，一行一个请求记录
- 当前写入文件保持未压缩，便于实时查看
- 轮转后的旧日志使用 gzip 压缩
- 默认单文件 50 MB
- 默认保留 7 天
- 日志保存在 `~/.relaydog/logs`

安全提醒：

- 请求日志可能包含 API Key、Header、Prompt、响应正文等敏感信息
- 默认关闭
- 仅建议在本机调试时临时开启

## 安全

- 默认仅监听 `127.0.0.1`
- API Key 明文存储于 `~/.relaydog/config.json`
- 不上传配置、日志或请求数据
- 请求日志默认关闭
- 开启请求日志后会记录真实 Header、Body 和响应内容
- 当前产品定位为本机个人工具，不提供配置加密和日志脱敏

## 技术栈

- Swift 6.1
- SwiftUI
- AppKit / NSStatusItem
- Network.framework
- URLSession
- async/await
- Swift Package Manager

## 产品原则

- 默认透明代理
- 不做跨协议转换
- 显式配置才改写模型名
- 本机优先，不依赖云端服务
- 菜单栏用于高频操作，Settings 用于配置管理
- 面向 Codex、Claude Code 与 OpenAI 兼容生态
- 本地可观测，方便排查真实请求数据
