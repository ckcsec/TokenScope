import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginController: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var requiresApproval = false
    @Published var errorMessage: String?
    private let language: LanguageController

    var isInstalledInApplications: Bool {
        let appPath = Bundle.main.bundleURL.standardizedFileURL.path
        let systemApplications = "/Applications/"
        let userApplications = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications")
            .standardizedFileURL.path + "/"
        return appPath.hasPrefix(systemApplications) || appPath.hasPrefix(userApplications)
    }

    init(language: LanguageController) {
        self.language = language
        refresh()
    }

    func setEnabled(_ enabled: Bool) {
        if enabled, !isInstalledInApplications {
            errorMessage = language.text(
                "请先把 TokenScope 拖入“应用程序”文件夹，再开启开机自启。",
                "請先把 TokenScope 拖入「應用程式」資料夾，再開啟登入時啟動。",
                "Move TokenScope to the Applications folder before enabling launch at login."
            )
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
            errorMessage = language.text(
                "无法更新开机自启：\(error.localizedDescription)",
                "無法更新登入時啟動：\(error.localizedDescription)",
                "Could not update launch at login: \(error.localizedDescription)"
            )
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
