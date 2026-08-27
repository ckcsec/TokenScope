<p align="center">
  <img src="docs/TokenScope.png" width="96" alt="TokenScope icon">
</p>

<h1 align="center">TokenScope</h1>

<p align="center">macOS 菜单栏里的本地 AI Agent Token、请求数与 API 等值成本面板。</p>

<p align="center">
  <a href="https://github.com/ckcsec/TokenScope/releases/latest"><img src="https://img.shields.io/github/v/release/ckcsec/TokenScope?display_name=tag" alt="GitHub release"></a>
  <img src="https://img.shields.io/badge/macOS-13%2B-111827?logo=apple" alt="macOS 13+">
  <img src="https://img.shields.io/badge/Apple%20Silicon%20%7C%20Intel-Universal-4F7CFF" alt="Universal app">
  <a href="LICENSE"><img src="https://img.shields.io/github/license/ckcsec/TokenScope" alt="MIT license"></a>
</p>

![TokenScope 用量仪表盘](docs/dashboard-zh-Hans.png)

## 下载与安装

从 [GitHub Releases](https://github.com/ckcsec/TokenScope/releases/latest) 下载最新的 `TokenScope-*-macOS-universal.dmg`，打开后将 TokenScope 拖入“应用程序”文件夹。

当前公开包采用本地签名，尚未经过 Apple 公证。首次启动如被 macOS 拦截，请在 Finder 中右键 TokenScope，选择“打开”，再确认一次。不要从非本仓库的第三方下载站获取安装包。

系统要求：macOS 13 Ventura 或更高版本，支持 Apple Silicon 与 Intel Mac。

## 功能

- 启动即打开主窗口；关闭窗口后驻留状态栏，点击图标随时重新打开，右键图标可直接退出
- 统计总 Token、输入、输出、缓存、总请求数与 API 等值成本
- 按 Agent、Provider、模型和日期拆分用量
- 趋势图悬停显示当日 Token、缓存 Token、缓存命中率与请求数
- 简体中文、繁体中文和英文即时切换
- 后台常驻，可由用户主动开启登录时启动
- 本地缓存与增量扫描，大型历史日志也能快速打开面板
- 仅展示实际读取到用量的数据源，不用预设列表冒充支持
- 价格表默认每 24 小时从本仓库自动更新，失败时回退内置公开模型价格（可在设置中关闭）

## 数据源

| 数据源 | 本地位置 | 统计内容 | 费用口径 |
| --- | --- | --- | --- |
| Claude Code | `~/.claude/projects/**/*.jsonl` | 输入、输出、缓存、请求、模型 | 日志金额或模型价格估算 |
| Codex | `~/.codex/sessions/**/*.jsonl` | 输入、输出、缓存、请求、模型 | 日志金额或模型价格估算 |
| Cursor | `state.vscdb` | Agent 请求、模型、请求时上下文 Token | 不推测订阅实付费用 |
| Grok Build | `~/.grok/sessions` | 逐请求 Token、模型调用数、服务返回费用 | 优先使用会话精确费用 |
| ZCode | `~/.zcode/cli/db/db.sqlite` | 输入、输出、推理、缓存、请求、模型 | 日志金额或模型价格估算 |

费用不是银行卡或订阅账单。TokenScope 优先采用日志里的实际金额，否则使用远程价格目录（`pricing.json`，每 24 小时自动更新一次、失败自动回退）或内置公开模型价格计算 API 等值成本。Cursor 目前只提供请求发起时的上下文 Token，因此显示用量和模型，但不虚构费用。

<table>
  <tr>
    <td><img src="docs/dashboard-zh-Hans.png" alt="TokenScope dashboard"></td>
    <td><img src="docs/data-sources-zh-Hans.png" alt="TokenScope data sources"></td>
  </tr>
  <tr>
    <td align="center">用量、成本与趋势</td>
    <td align="center">真实数据源状态</td>
  </tr>
</table>

## 隐私

TokenScope 不包含账号、广告、分析 SDK、遥测或云同步。日志和 SQLite 数据库仅在本机只读解析，不上传提示词、回复正文、Token 元数据或费用数据。应用唯一的网络请求是下载本仓库的 `pricing.json` 价格目录（纯下载、不上传任何数据），可在设置中关闭。应用只保存最近一次统计缓存、价格目录缓存和界面偏好。详见 [隐私说明](PRIVACY_POLICY.md)。

## 从源码运行

```bash
git clone https://github.com/ckcsec/TokenScope.git
cd TokenScope
swift build
swift run TokenScope
```

也可以打开 `TokenScope.xcodeproj` 直接运行。命令行只输出汇总、不输出对话正文：

```bash
swift run TokenScope --scan-once
```

运行测试并创建 Universal 安装包：

```bash
swift test
./scripts/make_release.sh
./scripts/verify_release.sh
```

若配置了 Developer ID 和公证凭据，可通过 `CODESIGN_IDENTITY` 与 `NOTARY_PROFILE` 环境变量生成无 Gatekeeper 警告的发行包。

## 致谢

TokenScope 的本机统计与价格估算思路早期受 [CC Switch](https://github.com/farion1231/cc-switch) 等本地工具生态启发。TokenScope 现已完全独立，不依赖、不捆绑任何第三方应用：价格数据来自内置的公开模型价格表，用量统计只读取各 Agent 自身的本机日志。

## 参与贡献

欢迎通过 [Issues](https://github.com/ckcsec/TokenScope/issues) 报告新的 Agent 日志格式、统计偏差或界面问题。提交新数据源支持时，请只提供脱敏后的字段结构，不要上传真实提示词、回复或凭据。

## License

[MIT](LICENSE)
