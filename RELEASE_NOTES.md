# TokenScope 1.1.0

- 彻底移除 CC Switch 依赖；价格表改为内置 + 每 24 小时自动从仓库 `pricing.json` 更新，失败自动回退，可在设置中关闭
- 新增 GLM-5.3 / GLM-5.3-Flash / Kimi K3 / Qwen3.8-Max / DeepSeek V4-Flash 价格，按 8 月官方新价更新 DeepSeek V4-Pro，修正 Claude Opus 5 官方定价
- 启动即显示主窗口；关闭窗口后驻留状态栏，点击图标重新打开、右键菜单退出
- Codex 会话模型归属改为从会话文件自身的 turn_context 解析，不再依赖外部状态数据库
- 面板底部新增 GitHub 项目链接

# TokenScope 1.0.0

首个 GitHub 公开版本。TokenScope 是一个完全在本机运行的 macOS AI Agent Token 用量面板。

## 主要功能

- 启动显示主窗口，关闭后驻留菜单栏，点击图标重新打开、右键退出
- 支持 Claude Code、Codex、Cursor、Grok Build 与 ZCode 的真实本地用量
- 内置公开模型价格表，覆盖主流国际与区域模型
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
