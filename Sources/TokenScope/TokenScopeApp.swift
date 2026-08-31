import AppKit
import Combine
import SwiftUI

@main
struct TokenScopeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

let TokenScopeRepoURL = URL(string: "https://github.com/ckcsec/TokenScope")!

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var mainWindow: NSWindow?
    private let language: LanguageController
    private let dataSources: DataSourceAccessManager
    private let store: UsageStore
    private let launchAtLogin: LaunchAtLoginController
    private var languageObserver: AnyCancellable?

    override init() {
        let language = LanguageController()
        #if DEBUG
        if let index = CommandLine.arguments.firstIndex(of: "--preview-language"),
           CommandLine.arguments.indices.contains(index + 1),
           let previewLanguage = AppLanguage(rawValue: CommandLine.arguments[index + 1]) {
            language.current = previewLanguage
        }
        #endif
        let dataSources = DataSourceAccessManager(language: language)
        self.language = language
        self.dataSources = dataSources
        self.store = UsageStore(dataSources: dataSources)
        self.launchAtLogin = LaunchAtLoginController(language: language)
        super.init()
        languageObserver = language.$current.sink { [weak self] _ in
            self?.updateStatusItemTooltip()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--scan-once") {
            runScanOnce()
            return
        }

        configureStatusItem()
        showMainWindow()
        #if DEBUG
        if CommandLine.arguments.contains("--preview-demo") {
            store.showDemo()
            return
        }
        #endif
        store.refresh()
        store.startAutoRefresh()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showMainWindow()
            return false
        }
        return true
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "chart.bar.xaxis", accessibilityDescription: "TokenScope")
        item.button?.image?.isTemplate = true
        item.button?.imagePosition = .imageOnly
        item.button?.title = ""
        item.button?.toolTip = statusItemTooltip
        item.button?.target = self
        item.button?.action = #selector(handleStatusItemClick(_:))
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item
    }

    @objc private func handleStatusItemClick(_ sender: AnyObject?) {
        guard NSApp.currentEvent?.type == .rightMouseUp else {
            toggleMainWindow()
            return
        }
        statusItem?.menu = makeStatusMenu()
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    private func toggleMainWindow() {
        guard let mainWindow else { return }
        if mainWindow.isVisible && !mainWindow.isMiniaturized {
            mainWindow.orderOut(nil)
        } else {
            showMainWindow()
            store.refresh()
        }
    }

    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()

        let githubItem = NSMenuItem(title: "GitHub", action: #selector(openGitHub), keyEquivalent: "")
        githubItem.target = self
        menu.addItem(githubItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: language.text("退出 TokenScope", "結束 TokenScope", "Quit TokenScope"),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = NSApp
        menu.addItem(quitItem)

        return menu
    }

    @objc private func openGitHub() {
        NSWorkspace.shared.open(TokenScopeRepoURL)
    }

    private func showMainWindow() {
        if let mainWindow {
            if mainWindow.isMiniaturized {
                mainWindow.deminiaturize(nil)
            }
            mainWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            launchAtLogin.refresh()
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1040, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "TokenScope"
        window.isReleasedWhenClosed = false
        window.center()
        window.contentViewController = NSHostingController(
            rootView: TokenScopeRootView(
                store: store,
                launchAtLogin: launchAtLogin,
                dataSources: dataSources
            )
            .environmentObject(language)
        )
        mainWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        launchAtLogin.refresh()
    }

    private var statusItemTooltip: String {
        language.text(
            "TokenScope · 点击查看今日用量",
            "TokenScope · 點擊查看今天用量",
            "TokenScope · Click to view today's usage"
        )
    }

    private func updateStatusItemTooltip() {
        statusItem?.button?.toolTip = statusItemTooltip
    }

    private func runScanOnce() {
        Task.detached(priority: .userInitiated) {
            let locations = UsageSourceLocations.automaticDefaults
            let snapshot = UsageScanner().scan(locations: locations)
            let overview = snapshot.overview(period: .all)
            let summary: [String: Any] = [
                "generatedAt": ISO8601DateFormatter().string(from: snapshot.generatedAt),
                "records": snapshot.records.count,
                "scannedFiles": snapshot.scannedFiles,
                "totalTokens": overview.total.total,
                "totalRequests": overview.requestCount,
                "totalCostUSD": overview.costUSD,
                "pricedRequests": overview.pricedRequestCount,
                "exactCostRequests": overview.exactCostRequestCount,
                "estimatedCostRequests": overview.estimatedCostRequestCount,
                "inputTokens": overview.total.input,
                "cachedInputTokens": overview.total.cachedInput,
                "cacheWriteTokens": overview.total.cacheWrite,
                "outputTokens": overview.total.output,
                "toolsWithUsage": overview.tools.map { ["name": $0.name, "tokens": $0.usage.total, "costUSD": $0.costUSD, "requests": $0.requestCount] },
                "modelsWithUsage": overview.models.map { ["name": $0.name, "tokens": $0.usage.total, "costUSD": $0.costUSD, "requests": $0.requestCount] }
            ]
            if let data = try? JSONSerialization.data(withJSONObject: summary, options: [.prettyPrinted, .sortedKeys]),
               let text = String(data: data, encoding: .utf8) {
                print(text)
            }
            exit(0)
        }
    }
}
