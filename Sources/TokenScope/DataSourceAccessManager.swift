import AppKit
import Combine
import Foundation

enum UsageDataSourceKind: String, CaseIterable, Identifiable {
    case claudeCode
    case codex
    case ccSwitch
    case cursor
    case grok
    case zcode

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .claudeCode:
            return "a.circle.fill"
        case .codex:
            return "command.circle.fill"
        case .ccSwitch:
            return "dollarsign.circle.fill"
        case .cursor:
            return "cursorarrow.motionlines"
        case .grok:
            return "xmark.circle.fill"
        case .zcode:
            return "z.square.fill"
        }
    }

    var expectedFolderName: String {
        switch self {
        case .claudeCode:
            return ".claude"
        case .codex:
            return ".codex"
        case .ccSwitch:
            return ".cc-switch"
        case .cursor:
            return "Cursor"
        case .grok:
            return ".grok"
        case .zcode:
            return ".zcode"
        }
    }

    fileprivate var bookmarkKey: String {
        "dataSourceBookmark.\(rawValue)"
    }
}

struct UsageSourceLocations: Sendable {
    var claudeRoot: URL?
    var codexRoot: URL?
    var ccSwitchRoot: URL?
    var cursorRoot: URL?
    var grokRoot: URL?
    var zcodeRoot: URL?

    static let empty = UsageSourceLocations()

    static var automaticDefaults: UsageSourceLocations {
        let fileManager = FileManager.default
        let home = FileManager.default.homeDirectoryForCurrentUser
        let applicationSupport = home.appendingPathComponent("Library/Application Support", isDirectory: true)

        func existing(_ candidates: [URL]) -> URL? {
            candidates.first { fileManager.fileExists(atPath: $0.path) }
        }

        return UsageSourceLocations(
            claudeRoot: existing([home.appendingPathComponent(".claude", isDirectory: true)]),
            codexRoot: existing([home.appendingPathComponent(".codex", isDirectory: true)]),
            ccSwitchRoot: existing([
                home.appendingPathComponent(".cc-switch", isDirectory: true),
                applicationSupport.appendingPathComponent("cc-switch", isDirectory: true)
            ]),
            cursorRoot: existing([applicationSupport.appendingPathComponent("Cursor", isDirectory: true)]),
            grokRoot: existing([home.appendingPathComponent(".grok", isDirectory: true)]),
            zcodeRoot: existing([home.appendingPathComponent(".zcode", isDirectory: true)])
        )
    }

    var claudeProjectsURL: URL? {
        guard let claudeRoot else { return nil }
        return claudeRoot.lastPathComponent == "projects"
            ? claudeRoot
            : claudeRoot.appendingPathComponent("projects", isDirectory: true)
    }

    var codexSessionsURL: URL? {
        guard let codexRoot else { return nil }
        return codexRoot.lastPathComponent == "sessions"
            ? codexRoot
            : codexRoot.appendingPathComponent("sessions", isDirectory: true)
    }

    var codexDatabaseURL: URL? {
        guard let codexRoot else { return nil }
        let root = codexRoot.lastPathComponent == "sessions" ? codexRoot.deletingLastPathComponent() : codexRoot
        return root.appendingPathComponent("state_5.sqlite")
    }

    var ccSwitchDatabaseURL: URL? {
        guard let ccSwitchRoot else { return nil }
        return ccSwitchRoot.pathExtension == "db"
            ? ccSwitchRoot
            : ccSwitchRoot.appendingPathComponent("cc-switch.db")
    }

    var cursorDatabaseURL: URL? {
        guard let cursorRoot else { return nil }
        if cursorRoot.pathExtension == "vscdb" {
            return cursorRoot
        }
        if cursorRoot.lastPathComponent == "globalStorage" {
            return cursorRoot.appendingPathComponent("state.vscdb")
        }
        return cursorRoot.appendingPathComponent("User/globalStorage/state.vscdb")
    }

    var zcodeDatabaseURL: URL? {
        guard let zcodeRoot else { return nil }
        if zcodeRoot.pathExtension == "sqlite" || zcodeRoot.pathExtension == "db" {
            return zcodeRoot
        }
        return zcodeRoot.appendingPathComponent("cli/db/db.sqlite")
    }

    var grokSessionsURL: URL? {
        guard let grokRoot else { return nil }
        return grokRoot.lastPathComponent == "sessions"
            ? grokRoot
            : grokRoot.appendingPathComponent("sessions", isDirectory: true)
    }

    var securityScopedRoots: [URL] {
        var seen = Set<String>()
        return [claudeRoot, codexRoot, ccSwitchRoot, cursorRoot, grokRoot, zcodeRoot].compactMap { url in
            guard let url else { return nil }
            let path = url.standardizedFileURL.path
            guard seen.insert(path).inserted else { return nil }
            return url
        }
    }

    var hasUsageSource: Bool {
        claudeRoot != nil || codexRoot != nil || cursorRoot != nil || grokRoot != nil || zcodeRoot != nil
    }
}

enum UsageSourceAccessMode {
    case automatic
    case authorized
    case unavailable
}

@MainActor
final class DataSourceAccessManager: ObservableObject {
    @Published private(set) var locations: UsageSourceLocations = .empty
    @Published private(set) var automaticKinds = Set<UsageDataSourceKind>()
    @Published var errorMessage: String?

    private let defaults: UserDefaults
    private let language: LanguageController
    private let fileManager = FileManager.default

    var isSandboxed: Bool {
        ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
            || FileManager.default.homeDirectoryForCurrentUser.path.contains("/Library/Containers/")
    }

    private var userHomeURL: URL {
        let sandboxHome = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL
        let containerMarker = "/Library/Containers/"
        guard let markerRange = sandboxHome.path.range(of: containerMarker) else {
            return sandboxHome
        }
        return URL(fileURLWithPath: String(sandboxHome.path[..<markerRange.lowerBound]), isDirectory: true)
    }

    init(language: LanguageController, defaults: UserDefaults = .standard) {
        self.language = language
        self.defaults = defaults
        reloadBookmarks()
        if !isSandboxed {
            applyAutomaticDefaults()
        }
    }

    func isConfigured(_ kind: UsageDataSourceKind) -> Bool {
        url(for: kind) != nil
    }

    func accessMode(for kind: UsageDataSourceKind) -> UsageSourceAccessMode {
        if automaticKinds.contains(kind) { return .automatic }
        return url(for: kind) == nil ? .unavailable : .authorized
    }

    func displayPath(for kind: UsageDataSourceKind) -> String {
        guard let url = url(for: kind) else {
            return language.text("未授权", "未授權", "Not authorized")
        }
        let path = url.path.replacingOccurrences(
            of: userHomeURL.path,
            with: "~"
        )
        if automaticKinds.contains(kind) {
            return language.text("自动 · \(path)", "自動 · \(path)", "Auto · \(path)")
        }
        return path
    }

    @discardableResult
    func choose(_ kind: UsageDataSourceKind) -> Bool {
        let panel = NSOpenPanel()
        let sourceName = language.sourceName(kind)
        panel.title = language.text("授权读取 \(sourceName) 数据", "授權讀取 \(sourceName) 資料", "Allow access to \(sourceName) data")
        panel.message = language.text(
            "请选择 \(kind.expectedFolderName) 文件夹。TokenScope 只读取 Token、模型和价格元数据。",
            "請選擇 \(kind.expectedFolderName) 資料夾。TokenScope 只讀取 Token、模型和價格中繼資料。",
            "Choose the \(kind.expectedFolderName) folder. TokenScope only reads token, model, and pricing metadata."
        )
        panel.prompt = language.text("授权读取", "授權讀取", "Allow Read Access")
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.showsHiddenFiles = true
        panel.directoryURL = kind == .cursor
            ? userHomeURL.appendingPathComponent("Library/Application Support", isDirectory: true)
            : userHomeURL

        guard panel.runModal() == .OK, let selectedURL = panel.url else { return false }
        guard validate(selectedURL, for: kind) else {
            errorMessage = language.text(
                "所选文件夹中未找到 \(sourceName) 所需的数据。请选择 \(kind.expectedFolderName) 文件夹。",
                "所選資料夾中找不到 \(sourceName) 所需的資料。請選擇 \(kind.expectedFolderName) 資料夾。",
                "The selected folder does not contain \(sourceName) data. Choose the \(kind.expectedFolderName) folder."
            )
            return false
        }

        do {
            let bookmark = try selectedURL.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            defaults.set(bookmark, forKey: kind.bookmarkKey)
            setURL(selectedURL, for: kind)
            automaticKinds.remove(kind)
            errorMessage = nil
            return true
        } catch {
            errorMessage = language.text(
                "无法保存文件夹授权：\(error.localizedDescription)",
                "無法儲存資料夾授權：\(error.localizedDescription)",
                "Could not save folder access: \(error.localizedDescription)"
            )
            return false
        }
    }

    func remove(_ kind: UsageDataSourceKind) {
        defaults.removeObject(forKey: kind.bookmarkKey)
        setURL(nil, for: kind)
        automaticKinds.remove(kind)
        if !isSandboxed {
            applyAutomaticDefault(for: kind)
        }
    }

    private func applyAutomaticDefaults() {
        for kind in UsageDataSourceKind.allCases where url(for: kind) == nil {
            applyAutomaticDefault(for: kind)
        }
    }

    private func applyAutomaticDefault(for kind: UsageDataSourceKind) {
        let defaults = UsageSourceLocations.automaticDefaults
        let fallback: URL?
        switch kind {
        case .claudeCode:
            fallback = defaults.claudeRoot
        case .codex:
            fallback = defaults.codexRoot
        case .ccSwitch:
            fallback = defaults.ccSwitchRoot
        case .cursor:
            fallback = defaults.cursorRoot
        case .grok:
            fallback = defaults.grokRoot
        case .zcode:
            fallback = defaults.zcodeRoot
        }
        guard let fallback else { return }
        setURL(fallback, for: kind)
        automaticKinds.insert(kind)
    }

    private func reloadBookmarks() {
        for kind in UsageDataSourceKind.allCases {
            guard let data = defaults.data(forKey: kind.bookmarkKey) else { continue }
            do {
                var isStale = false
                let url = try URL(
                    resolvingBookmarkData: data,
                    options: [.withSecurityScope, .withoutUI],
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                setURL(url, for: kind)
                if isStale {
                    refreshBookmark(for: kind, url: url)
                }
            } catch {
                defaults.removeObject(forKey: kind.bookmarkKey)
            }
        }
    }

    private func refreshBookmark(for kind: UsageDataSourceKind, url: URL) {
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart { url.stopAccessingSecurityScopedResource() }
        }
        guard let data = try? url.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }
        defaults.set(data, forKey: kind.bookmarkKey)
    }

    private func validate(_ url: URL, for kind: UsageDataSourceKind) -> Bool {
        switch kind {
        case .claudeCode:
            return url.lastPathComponent == "projects"
                || fileManager.fileExists(atPath: url.appendingPathComponent("projects").path)
        case .codex:
            return url.lastPathComponent == "sessions"
                || fileManager.fileExists(atPath: url.appendingPathComponent("sessions").path)
                || fileManager.fileExists(atPath: url.appendingPathComponent("state_5.sqlite").path)
        case .ccSwitch:
            return fileManager.fileExists(atPath: url.appendingPathComponent("cc-switch.db").path)
                || (url.pathExtension == "db" && fileManager.fileExists(atPath: url.path))
        case .cursor:
            return fileManager.fileExists(atPath: url.appendingPathComponent("User/globalStorage/state.vscdb").path)
                || fileManager.fileExists(atPath: url.appendingPathComponent("state.vscdb").path)
                || (url.pathExtension == "vscdb" && fileManager.fileExists(atPath: url.path))
        case .grok:
            return url.lastPathComponent == "sessions"
                || fileManager.fileExists(atPath: url.appendingPathComponent("sessions").path)
        case .zcode:
            return fileManager.fileExists(atPath: url.appendingPathComponent("cli/db/db.sqlite").path)
                || ((url.pathExtension == "sqlite" || url.pathExtension == "db") && fileManager.fileExists(atPath: url.path))
        }
    }

    private func url(for kind: UsageDataSourceKind) -> URL? {
        switch kind {
        case .claudeCode:
            return locations.claudeRoot
        case .codex:
            return locations.codexRoot
        case .ccSwitch:
            return locations.ccSwitchRoot
        case .cursor:
            return locations.cursorRoot
        case .grok:
            return locations.grokRoot
        case .zcode:
            return locations.zcodeRoot
        }
    }

    private func setURL(_ url: URL?, for kind: UsageDataSourceKind) {
        switch kind {
        case .claudeCode:
            locations.claudeRoot = url
        case .codex:
            locations.codexRoot = url
        case .ccSwitch:
            locations.ccSwitchRoot = url
        case .cursor:
            locations.cursorRoot = url
        case .grok:
            locations.grokRoot = url
        case .zcode:
            locations.zcodeRoot = url
        }
    }
}
