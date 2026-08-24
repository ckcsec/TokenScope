import AppKit
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

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private let store = UsageStore()
    private let launchAtLogin = LaunchAtLoginController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--scan-once") {
            runScanOnce()
            return
        }

        NSApplication.shared.setActivationPolicy(.accessory)
        configurePopover()
        configureStatusItem()
        store.refresh()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "chart.bar.xaxis", accessibilityDescription: "TokenScope")
        item.button?.image?.isTemplate = true
        item.button?.imagePosition = .imageOnly
        item.button?.title = ""
        item.button?.toolTip = "TokenScope · 点击查看今日用量"
        item.button?.target = self
        item.button?.action = #selector(togglePopover(_:))
        statusItem = item
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 1040, height: 720)
        popover.contentViewController = NSHostingController(
            rootView: TokenScopeRootView(store: store, launchAtLogin: launchAtLogin)
        )
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            launchAtLogin.refresh()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            store.refresh()
        }
    }

    private func runScanOnce() {
        Task.detached(priority: .userInitiated) {
            let snapshot = UsageScanner().scan()
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
