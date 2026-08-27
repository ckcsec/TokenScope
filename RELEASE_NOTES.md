# TokenScope 1.0.0

首个 GitHub 公开版本。TokenScope 是一个完全在本机运行的 macOS AI Agent Token 用量面板。

## 主要功能

- 菜单栏纯图标入口，点击显示 Token、请求数和 API 等值成本
- 支持 Claude Code、Codex、Cursor、Grok Build 与 ZCode 的真实本地用量
- 使用 CC Switch 本机价格表，并提供常见模型价格兜底
- Agent、Provider、模型、日期四个维度的统计与排行
- 趋势图悬停查看 Token、缓存 Token、缓存命中率和请求数
- 简体中文、繁体中文、英文即时切换
- 异步缓存、周期聚合缓存与增量日志扫描
- 后台常驻和用户主动开启的登录时启动
- Universal 2，支持 Apple Silicon 与 Intel，最低 macOS 13

## 安装

下载 DMG，打开后将 TokenScope 拖入“应用程序”文件夹。当前包尚未经过 Apple 公证，首次启动请在 Finder 中右键 TokenScope 并选择“打开”。

## 说明

- 所有日志只在本机只读解析，不上传提示词、回复或统计数据。
- Cursor 本地字段是请求时上下文 Token，不代表实际输入/输出账单，因此不计算 Cursor 订阅费用。
- Grok Build 只有在 `~/.grok/sessions` 中产生会话用量后才会展示。
