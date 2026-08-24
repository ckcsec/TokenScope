import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginController: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var requiresApproval = false
    @Published var errorMessage: String?

    var isInstalledInApplications: Bool {
        let appPath = Bundle.main.bundleURL.standardizedFileURL.path
        let systemApplications = "/Applications/"
        let userApplications = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications")
            .standardizedFileURL.path + "/"
        return appPath.hasPrefix(systemApplications) || appPath.hasPrefix(userApplications)
    }

    init() {
        refresh()
    }

    func setEnabled(_ enabled: Bool) {
        if enabled, !isInstalledInApplications {
            errorMessage = "请先把 TokenScope 拖入“应用程序”文件夹，再开启开机自启。"
            return
        }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            errorMessage = nil
        } catch {
            errorMessage = "无法更新开机自启：\(error.localizedDescription)"
        }
        refresh()
    }

    func refresh() {
        let status = SMAppService.mainApp.status
        isEnabled = status == .enabled
        requiresApproval = status == .requiresApproval
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
