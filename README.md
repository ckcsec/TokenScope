# TokenScope

![TokenScope](docs/TokenScope.png)

TokenScope 是一个 macOS 菜单栏 token 用量面板。它会扫描本机常见 AI 编程 Agent 的本地日志，点击菜单栏纯图标即可查看总 token、总请求、预估成本、输入、缓存、输出、模型排行、Provider 分布和 Agent 覆盖情况。

[下载最新 macOS 安装包](https://github.com/ckcsec/TokenScope/releases/latest)

## 当前实现

- 已真实解析 Claude Code: `~/.claude/projects/**/*.jsonl`
- 已真实解析 Codex: `~/.codex/sessions/**/*.jsonl`，并用 `~/.codex/state_5.sqlite` 补充模型信息
- 已探测 Cursor: `~/Library/Application Support/Cursor`
- 已探测 ZCode: `~/Library/Application Support/ZCode`、`~/.zcode`
- 已探测 Grok CLI/Grok Bot/Grok Build: `~/.grok`、`~/.grokbot`、`~/Library/Application Support/Grok Bot`
- 已按 Claude Code `message.id` 去重，避免同一 assistant 消息重复计数
- 已按 Codex `total_token_usage` 累计差值去重，避免连续重复 token_count 事件虚高
- 总请求数按产生 token 的模型响应记录统计
- 费用优先使用日志中的实际金额，否则读取 `~/.cc-switch/cc-switch.db` 的模型单价估算；CC Switch 不存在时使用内置常见模型单价
- Agent、Provider 和模型排行均显示对应费用，无法匹配价格的请求不猜测金额
- 首页按今日工作量显示动态休息提醒
- 关闭面板后继续在菜单栏后台运行，退出需点击右上角电源按钮
- 使用 macOS `SMAppService` 提供开机自启开关；为避免 DMG 弹出后路径失效，需先拖入“应用程序”
- 已内置 CC Switch 风格 Provider 网格和常见 Agent 探测列表
- 不联网、不上传数据，只在本机汇总 token 元数据

Cursor、ZCode、Grok Build 这类工具如果本机日志没有公开稳定的 `input_tokens` / `output_tokens` / `total_tokens` 字段，TokenScope 会显示“已识别”，但不会猜测 token。Grok CLI 的精确 token 更适合通过它的 External OpenTelemetry `grok_code.token.usage` 指标接入。

## 构建

```bash
git clone https://github.com/ckcsec/TokenScope.git
cd TokenScope
./scripts/package_app.sh
open build/TokenScope.app
```

## 安装

从 GitHub Releases 下载 `TokenScope-v1.0.0-macOS-universal.dmg`，打开后把 TokenScope 拖到“应用程序”，再从“应用程序”启动。支持 Apple Silicon 与 Intel，最低需要 macOS 13。

当前公开包为 ad-hoc 完整性签名，因为发布机没有 Apple Developer ID 证书。首次打开时请在 Finder 中右键 TokenScope，选择“打开”，再确认一次。获得 Developer ID 后可运行：

```bash
CODESIGN_IDENTITY="Developer ID Application: YOUR NAME (TEAMID)" \
NOTARY_PROFILE="tokenscope-notary" \
./scripts/make_release.sh
```

这会启用 Hardened Runtime、提交 Apple 公证并装订公证票据。发布前可运行 `./scripts/verify_release.sh` 验证双架构、签名、DMG 与 ZIP。

## 数据与费用口径

TokenScope 不联网、不上传提示词或回复内容，只读取本机日志中的 token 元数据。总请求数按产生 token 的模型响应记录统计。费用优先使用日志金额，否则读取 CC Switch 的本机价格表，再使用内置价格兜底；订阅工具显示的是 API 等值预估，不等于实际账单。

## 快速验证扫描器

```bash
swift run TokenScope --scan-once
```

价格和 invoice 仍以各 Provider 后台为准。Codex、Claude Code 等订阅内使用产生的费用显示为 API 等值预估，不代表实际扣款。
