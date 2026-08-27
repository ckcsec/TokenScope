import Combine
import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case english = "en"

    var id: String { rawValue }

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    var displayName: String {
        switch self {
        case .simplifiedChinese:
            return "简体中文"
        case .traditionalChinese:
            return "繁體中文"
        case .english:
            return "English"
        }
    }

    var compactName: String {
        switch self {
        case .simplifiedChinese:
            return "简中"
        case .traditionalChinese:
            return "繁中"
        case .english:
            return "EN"
        }
    }
}

@MainActor
final class LanguageController: ObservableObject {
    @Published var current: AppLanguage {
        didSet {
            defaults.set(current.rawValue, forKey: Self.defaultsKey)
        }
    }

    private static let defaultsKey = "appLanguage"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let saved = defaults.string(forKey: Self.defaultsKey),
           let language = AppLanguage(rawValue: saved) {
            current = language
        } else if Locale.preferredLanguages.first?.lowercased().contains("hant") == true {
            current = .traditionalChinese
        } else if Locale.preferredLanguages.first?.lowercased().hasPrefix("zh") == true {
            current = .simplifiedChinese
        } else {
            current = .english
        }
    }

    func text(_ simplified: String, _ traditional: String, _ english: String) -> String {
        switch current {
        case .simplifiedChinese:
            return simplified
        case .traditionalChinese:
            return traditional
        case .english:
            return english
        }
    }

    func periodLabel(_ period: UsagePeriod) -> String {
        switch period {
        case .today:
            return text("今天", "今天", "Today")
        case .week:
            return text("7 天", "7 天", "7 days")
        case .month:
            return text("30 天", "30 天", "30 days")
        case .all:
            return text("全部", "全部", "All")
        }
    }

    func statusLabel(_ status: ToolSupportStatus) -> String {
        switch status {
        case .liveData:
            return text("有用量", "有用量", "Usage found")
        case .detected:
            return text("已识别", "已識別", "Detected")
        case .preset:
            return text("预设", "預設", "Preset")
        }
    }

    func sourceName(_ kind: UsageDataSourceKind) -> String {
        switch kind {
        case .claudeCode:
            return "Claude Code"
        case .codex:
            return "Codex"
        case .ccSwitch:
            return text("CC Switch 价格", "CC Switch 價格", "CC Switch pricing")
        case .cursor:
            return "Cursor"
        case .grok:
            return "Grok Build"
        case .zcode:
            return "ZCode"
        }
    }

    func categoryLabel(_ category: String) -> String {
        let translations: [String: (String, String)] = [
            "Foundation": ("基础模型", "基礎模型"),
            "Coding": ("编程", "程式開發"),
            "Agent": ("智能体", "代理工具"),
            "Router": ("聚合路由", "聚合路由"),
            "Cloud": ("云服务", "雲端服務"),
            "Inference": ("推理服务", "推理服務"),
            "Model Hub": ("模型社区", "模型社群"),
            "Search": ("搜索", "搜尋"),
            "Custom": ("自定义", "自訂")
        ]
        guard current != .english, let translated = translations[category] else { return category }
        return current == .simplifiedChinese ? translated.0 : translated.1
    }

    func providerName(_ provider: ProviderPreset) -> String {
        guard provider.id == "custom" else { return provider.name }
        return text("自定义配置", "自訂設定", "Custom configuration")
    }

    func agentNote(_ agent: AgentToolInfo) -> String {
        switch agent.id {
        case "claude-code":
            return text("读取 Claude Code 本地 JSONL 用量", "讀取 Claude Code 本機 JSONL 用量", "Reads local Claude Code JSONL usage")
        case "codex":
            return text("读取 Codex 本地会话 Token", "讀取 Codex 本機工作階段 Token", "Reads tokens from local Codex sessions")
        case "cc-switch":
            return text("读取 CC Switch 模型价格目录", "讀取 CC Switch 模型價格目錄", "Reads the CC Switch model pricing catalog")
        case "cursor":
            return text("读取 Cursor 请求、模型和上下文 Token", "讀取 Cursor 請求、模型和內容 Token", "Reads Cursor requests, models, and context tokens")
        case "grok-build":
            return text("读取 Grok Build 本机会话 Token", "讀取 Grok Build 本機工作階段 Token", "Reads tokens from local Grok Build sessions")
        case "zcode":
            return text("读取 ZCode 精确模型用量", "讀取 ZCode 精確模型用量", "Reads exact ZCode model usage")
        default:
            return text("从本机应用或配置目录识别", "從本機應用程式或設定資料夾識別", "Detected from local app or configuration folders")
        }
    }
}
