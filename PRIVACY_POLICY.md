# TokenScope 隐私说明

生效日期：2026 年 8 月 27 日

TokenScope 是一款完全在 macOS 本机运行的 AI Agent Token 用量统计工具。

## 本地数据访问

TokenScope 只读访问本机已支持 Agent 的日志、状态数据库和价格数据库，从中提取时间、模型、Provider、Token 数量、请求数和费用元数据。应用不会提取或保留提示词与回复正文。

## 数据收集

当前版本没有账号系统、广告、分析 SDK、远程遥测或云同步，不会把提示词、回复、文件内容、Token 元数据或费用数据发送给开发者或第三方服务器，也不进行跨 App 或跨网站跟踪。

## 本机存储

应用在 macOS 的 Application Support 和偏好目录中保存最近一次统计缓存、数据源选择与界面偏好。这些内容仅用于加快启动和恢复用户设置，卸载应用后可由用户自行删除。

## 费用说明

Provider 和 Agent 名称仅用于标识本机日志来源。费用优先采用日志中的金额，否则按本机 CC Switch 价格或公开模型价格估算，不代表订阅或银行卡实际账单。

## 联系

隐私问题可通过 [GitHub Issues](https://github.com/ckcsec/TokenScope/issues) 提交。请勿在 Issue 中粘贴提示词、回复、API Key 或未经脱敏的日志。
