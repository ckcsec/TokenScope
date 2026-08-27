import AppKit
import SwiftUI

private enum TokenScopePalette {
    static let canvas = Color(hex: "F5F7FB")
    static let canvasCool = Color(hex: "EAF2FF")
    static let canvasWarm = Color(hex: "FFF1EC")
    static let surface = Color.white
    static let surfaceMuted = Color(hex: "F8FAFD")
    static let ink = Color(hex: "172033")
    static let secondaryInk = Color(hex: "667085")
    static let border = Color(hex: "DDE3EC")
    static let blue = Color(hex: "4F7CFF")
    static let mint = Color(hex: "13B889")
    static let coral = Color(hex: "FF6B5E")
    static let violet = Color(hex: "7C6CF2")
    static let amber = Color(hex: "F5A524")
}

struct TokenScopeRootView: View {
    @EnvironmentObject private var language: LanguageController
    @ObservedObject var store: UsageStore
    @ObservedObject var launchAtLogin: LaunchAtLoginController
    @ObservedObject var dataSources: DataSourceAccessManager
    @State private var period: UsagePeriod = .week
    @State private var query = ""
    @State private var appliedQuery = ""
    @State private var queryTask: Task<Void, Never>?

    var overview: UsageOverview {
        store.overview(period: period, query: appliedQuery)
    }

    var todayOverview: UsageOverview {
        store.overview(period: .today)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    TokenScopePalette.canvasCool,
                    TokenScopePalette.canvas,
                    TokenScopePalette.canvasWarm.opacity(0.72)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: 16) {
                        summaryBand
                        DailyReminder(overview: todayOverview, launchAtLogin: launchAtLogin)
                        contentGrid
                        liveAgentSection
                        DataSourcePanel(dataSources: dataSources, store: store)
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 22)
                }
            }
        }
        .frame(minWidth: 960, minHeight: 660)
        .foregroundStyle(TokenScopePalette.ink)
        .tint(TokenScopePalette.blue)
        .onChange(of: query) { newValue in
            queryTask?.cancel()
            queryTask = Task {
                try? await Task.sleep(nanoseconds: 180_000_000)
                guard !Task.isCancelled else { return }
                appliedQuery = newValue
            }
        }
        .onDisappear {
            queryTask?.cancel()
        }
        .alert("TokenScope", isPresented: Binding(
            get: { launchAtLogin.errorMessage != nil },
            set: { if !$0 { launchAtLogin.errorMessage = nil } }
        )) {
            Button(language.text("好", "好", "OK")) {
                launchAtLogin.errorMessage = nil
            }
        } message: {
            Text(launchAtLogin.errorMessage ?? "")
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [TokenScopePalette.blue, TokenScopePalette.violet],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 3) {
                    Text("TokenScope")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(TokenScopePalette.ink)
                    Text(language.text(
                        "本机 AI Agent 用量与 API 等值成本",
                        "本機 AI Agent 用量與 API 等值成本",
                        "Local AI agent usage and API-equivalent cost"
                    ))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(TokenScopePalette.secondaryInk)
                }
            }

            Spacer()

            Picker("", selection: $period) {
                ForEach(UsagePeriod.allCases) { item in
                    Text(language.periodLabel(item)).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 210)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(language.text("搜索模型、Provider、Agent", "搜尋模型、Provider、Agent", "Search model or agent"), text: $query)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 12)
            .frame(width: 205, height: 36)
            .background(TokenScopePalette.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(TokenScopePalette.border))

            Button {
                store.refresh(force: true)
            } label: {
                Image(systemName: store.isScanning ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(IconButtonStyle())
            .help(language.text("重新扫描", "重新掃描", "Rescan"))
            .disabled(store.isScanning)

            Menu {
                Picker(language.text("语言", "語言", "Language"), selection: $language.current) {
                    ForEach(AppLanguage.allCases) { item in
                        Text(item.displayName).tag(item)
                    }
                }
            } label: {
                Label(language.current.compactName, systemImage: "globe")
                    .labelStyle(.titleAndIcon)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 66)
            .help(language.text("切换语言", "切換語言", "Change language"))

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(IconButtonStyle())
            .help(language.text("退出", "結束", "Quit"))
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .background(TokenScopePalette.surface.opacity(0.94))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(TokenScopePalette.border)
                .frame(height: 1)
        }
    }

    private var summaryBand: some View {
        HStack(spacing: 12) {
            HeroMetricCard(
                title: language.text("总 Token", "總 Token", "Total tokens"),
                value: formatTokens(overview.total.total),
                subtitle: store.isShowingDemo
                    ? language.text("演示数据", "示範資料", "Demo data")
                    : language.text(
                        "已扫描 \(store.snapshot.scannedFiles) 个本地数据文件",
                        "已掃描 \(store.snapshot.scannedFiles) 個本機資料檔案",
                        "Scanned \(store.snapshot.scannedFiles) local data files"
                    ),
                icon: "sum",
                tint: TokenScopePalette.blue
            )

            MetricTile(title: language.text("总成本", "總成本", "Total cost"), value: formatCurrency(overview.costUSD), footnote: costFootnote, icon: "dollarsign", tint: TokenScopePalette.amber)
            MetricTile(title: language.text("总请求数", "總請求數", "Requests"), value: formatCount(overview.requestCount), footnote: language.text("本机响应记录", "本機回應記錄", "Local responses"), icon: "arrow.up.arrow.down", tint: TokenScopePalette.violet)
            MetricTile(title: language.text("输入", "輸入", "Input"), value: formatTokens(overview.total.visibleInput), footnote: language.text("含 Cache", "含 Cache", "Includes cache"), icon: "arrow.down", tint: TokenScopePalette.mint)
            MetricTile(title: language.text("输出", "輸出", "Output"), value: formatTokens(overview.total.output + overview.total.reasoningOutput), footnote: language.text("含 Reasoning", "含 Reasoning", "Includes reasoning"), icon: "arrow.up", tint: TokenScopePalette.coral)
        }
    }

    private var costFootnote: String {
        guard overview.requestCount > 0 else { return language.text("暂无请求", "暫無請求", "No requests") }
        if overview.pricedRequestCount == overview.requestCount {
            return overview.exactCostRequestCount > 0
                ? language.text("日志金额 + API 预估", "日誌金額 + API 預估", "Reported + API estimate")
                : language.text("API 等值预估", "API 等值預估", "API-equivalent estimate")
        }
        return language.text(
            "\(overview.pricedRequestCount)/\(overview.requestCount) 次已计价",
            "\(overview.pricedRequestCount)/\(overview.requestCount) 次已計價",
            "\(overview.pricedRequestCount)/\(overview.requestCount) priced"
        )
    }

    private var contentGrid: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 16) {
                BreakdownPanel(
                    title: language.text("Agent 用量", "Agent 用量", "Agent usage"),
                    rows: Array(overview.tools.prefix(8)),
                    emptyText: language.text("还没有读到可统计的 Agent Token", "尚未讀到可統計的 Agent Token", "No agent token records found yet"),
                    tint: TokenScopePalette.blue
                )
                BreakdownPanel(
                    title: language.text("Provider 用量", "Provider 用量", "Provider usage"),
                    rows: Array(overview.providers.prefix(8)),
                    emptyText: language.text("读取模型后会自动归类 Provider", "讀取模型後會自動歸類 Provider", "Providers are classified from detected models"),
                    tint: TokenScopePalette.violet
                )
            }
            .frame(width: 330)

            VStack(spacing: 16) {
                TrendPanel(days: overview.days)
                ModelPanel(rows: Array(overview.models.prefix(10)))
            }
        }
    }

    @ViewBuilder
    private var liveAgentSection: some View {
        let liveAgents = store.snapshot.agents.filter { $0.status == .liveData }
        if !liveAgents.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    PanelTitle(
                        title: language.text("正在统计的 Agent", "正在統計的 Agent", "Tracked agents"),
                        tint: TokenScopePalette.violet
                    )
                    Spacer()
                    Text(language.text(
                        "仅显示本机已读取到真实用量的工具",
                        "僅顯示本機已讀取到真實用量的工具",
                        "Only agents with local usage are shown"
                    ))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                AgentStrip(agents: liveAgents)
            }
            .padding(16)
            .panelBackground()
        }
    }
}

struct DataSourcePanel: View {
    @EnvironmentObject private var language: LanguageController
    @ObservedObject var dataSources: DataSourceAccessManager
    @ObservedObject var store: UsageStore

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                HStack(spacing: 7) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(TokenScopePalette.blue.opacity(0.12))
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(TokenScopePalette.blue)
                    }
                    .frame(width: 28, height: 28)
                    Text(dataSources.isSandboxed
                         ? language.text("数据源授权", "資料來源授權", "Data source access")
                         : language.text("数据源自动发现", "資料來源自動探索", "Automatic data discovery"))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    Text(language.text("只读", "唯讀", "Read only"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(language.text(
                    "设置仅影响本机读取范围",
                    "設定僅影響本機讀取範圍",
                    "Settings only affect local read access"
                ))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Divider()

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 18), count: 3), spacing: 10) {
                ForEach(UsageDataSourceKind.allCases) { kind in
                    DataSourceControl(
                        kind: kind,
                        isConfigured: dataSources.isConfigured(kind),
                        isAutomatic: dataSources.accessMode(for: kind) == .automatic,
                        path: dataSources.displayPath(for: kind),
                        choose: {
                            if dataSources.choose(kind) {
                                store.reloadForSourceChange()
                            }
                        },
                        remove: {
                            dataSources.remove(kind)
                            store.reloadForSourceChange()
                        }
                    )
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .panelBackground()
        .alert(language.text("无法授权数据源", "無法授權資料來源", "Could not access data source"), isPresented: Binding(
            get: { dataSources.errorMessage != nil },
            set: { if !$0 { dataSources.errorMessage = nil } }
        )) {
            Button(language.text("好", "好", "OK")) {
                dataSources.errorMessage = nil
            }
        } message: {
            Text(dataSources.errorMessage ?? "")
        }
    }
}

private struct DataSourceControl: View {
    @EnvironmentObject private var language: LanguageController
    var kind: UsageDataSourceKind
    var isConfigured: Bool
    var isAutomatic: Bool
    var path: String
    var choose: () -> Void
    var remove: () -> Void

    var body: some View {
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill((isConfigured ? TokenScopePalette.mint : TokenScopePalette.secondaryInk).opacity(0.11))
                Image(systemName: kind.icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(isConfigured ? TokenScopePalette.mint : TokenScopePalette.secondaryInk)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(language.sourceName(kind))
                        .font(.system(size: 12, weight: .bold))
                    if isConfigured {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(TokenScopePalette.mint)
                    }
                }
                Text(path)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 4)

            Button(action: choose) {
                Image(systemName: isConfigured ? "folder.badge.gearshape" : "folder.badge.plus")
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.borderless)
            .help(isConfigured
                  ? language.text("更换数据文件夹", "更換資料資料夾", "Change data folder")
                  : language.text("授权文件夹", "授權資料夾", "Authorize folder"))

            if isConfigured && !isAutomatic {
                Button(action: remove) {
                    Image(systemName: "trash")
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help(language.text("移除授权", "移除授權", "Remove access"))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 42)
    }
}

struct DailyReminder: View {
    @EnvironmentObject private var language: LanguageController
    var overview: UsageOverview
    @ObservedObject var launchAtLogin: LaunchAtLoginController

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [TokenScopePalette.amber, TokenScopePalette.coral],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: reminderIcon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text(reminderText)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Text(language.text(
                    "今日 \(formatCount(overview.requestCount)) 次请求 · \(formatTokens(overview.total.total)) Token · \(formatCurrency(overview.costUSD)) 预估成本",
                    "今天 \(formatCount(overview.requestCount)) 次請求 · \(formatTokens(overview.total.total)) Token · \(formatCurrency(overview.costUSD)) 預估成本",
                    "Today: \(formatCount(overview.requestCount)) requests · \(formatTokens(overview.total.total)) tokens · \(formatCurrency(overview.costUSD)) estimated"
                ))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Toggle(language.text("开机自启", "登入時啟動", "Launch at login"), isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.setEnabled($0) }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .font(.system(size: 11, weight: .bold))
                .disabled(!launchAtLogin.isInstalledInApplications && !launchAtLogin.isEnabled)

                if launchAtLogin.requiresApproval {
                    Button(language.text("需要在系统设置中批准", "需要在系統設定中允許", "Approval required in System Settings")) {
                        launchAtLogin.openSystemSettings()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(TokenScopePalette.coral)
                } else if !launchAtLogin.isInstalledInApplications {
                    Text(language.text("拖入“应用程序”后可开启", "移入「應用程式」後可開啟", "Move to Applications to enable"))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(TokenScopePalette.coral)
                } else {
                    Text(language.text("后台常驻 · 数据仅保留在本机", "背景常駐 · 資料只保留在本機", "Runs in background · Data stays local"))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 62)
        .background(
            LinearGradient(
                colors: [Color(hex: "FFF7E8"), Color(hex: "FFF0EC")],
                startPoint: .leading,
                endPoint: .trailing
            ),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(TokenScopePalette.amber.opacity(0.24)))
    }

    private var reminderIcon: String {
        overview.requestCount >= 100 ? "figure.cooldown" : "cup.and.saucer.fill"
    }

    private var reminderText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if overview.requestCount == 0 {
            return hour < 12
                ? language.text(
                    "早上好，今天慢慢来，先做好最重要的一件事。",
                    "早安，今天慢慢來，先做好最重要的一件事。",
                    "Good morning. Take it steadily and start with what matters most."
                )
                : language.text(
                    "给自己留一点从容，准备好了再开始。",
                    "給自己留一點從容，準備好了再開始。",
                    "Give yourself some room. Begin when you are ready."
                )
        }
        if hour >= 18 {
            return language.text(
                "今天辛苦了，收尾时也记得照顾好自己。",
                "今天辛苦了，收尾時也記得照顧好自己。",
                "You worked hard today. Take care of yourself as you wrap up."
            )
        }
        if overview.requestCount >= 100 {
            return language.text(
                "今天完成了很多工作，辛苦了，先伸展一下再继续。",
                "今天完成了很多工作，辛苦了，先伸展一下再繼續。",
                "You have done a lot today. Stretch for a moment before continuing."
            )
        }
        if overview.requestCount >= 30 {
            return language.text(
                "进展很扎实，辛苦了，记得抬头放松一下眼睛。",
                "進展很扎實，辛苦了，記得抬頭放鬆一下眼睛。",
                "Solid progress. Look away from the screen and rest your eyes."
            )
        }
        return language.text(
            "已经迈出了今天的步子，辛苦了，记得喝口水。",
            "已經踏出了今天的步伐，辛苦了，記得喝口水。",
            "You are moving today forward. Take a moment for some water."
        )
    }
}

struct HeroMetricCard: View {
    var title: String
    var value: String
    var subtitle: String
    var icon: String
    var tint: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint, TokenScopePalette.violet],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TokenScopePalette.secondaryInk)
                Text(value)
                    .font(.system(size: 31, weight: .black, design: .rounded))
                    .foregroundStyle(TokenScopePalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(TokenScopePalette.secondaryInk)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 112)
        .background(
            LinearGradient(
                colors: [TokenScopePalette.surface, tint.opacity(0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(tint.opacity(0.22)))
        .shadow(color: tint.opacity(0.10), radius: 10, y: 5)
    }
}

private struct PanelTitle: View {
    var title: String
    var tint: Color

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(tint)
                .frame(width: 4, height: 18)
            Text(title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(TokenScopePalette.ink)
        }
    }
}

struct MetricTile: View {
    var title: String
    var value: String
    var footnote: String
    var icon: String
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(tint.opacity(0.13))
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(tint)
                }
                .frame(width: 28, height: 28)

                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(TokenScopePalette.secondaryInk)
                    .lineLimit(1)
            }
            Text(value)
                .font(.system(size: 23, weight: .black, design: .rounded))
                .foregroundStyle(TokenScopePalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(footnote)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(TokenScopePalette.secondaryInk)
                .lineLimit(2)
                .frame(minHeight: 24, alignment: .topLeading)
        }
        .padding(14)
        .frame(width: 132)
        .frame(minHeight: 112)
        .panelBackground()
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 2)
                .fill(tint)
                .frame(width: 34, height: 3)
                .padding(.top, 1)
        }
    }
}

struct BreakdownPanel: View {
    @EnvironmentObject private var language: LanguageController
    var title: String
    var rows: [UsageBreakdown]
    var emptyText: String
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelTitle(title: title, tint: tint)

            if rows.isEmpty {
                EmptyState(text: emptyText)
            } else {
                let maxValue = max(rows.map { $0.usage.total }.max() ?? 1, 1)
                VStack(spacing: 10) {
                    ForEach(rows) { row in
                        VStack(alignment: .leading, spacing: 7) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(row.name)
                                        .font(.system(size: 13, weight: .bold))
                                        .lineLimit(1)
                                    Text(row.subtitle)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(formatTokens(row.usage.total))
                                        .font(.system(size: 13, weight: .black, design: .rounded))
                                    Text(row.pricedRequestCount > 0 ? formatCurrency(row.costUSD) : language.text("未计价", "未計價", "Unpriced"))
                                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                            }

                            GeometryReader { proxy in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.black.opacity(0.06))
                                    .overlay(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(
                                                LinearGradient(
                                                    colors: [tint, tint.opacity(0.72)],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .frame(width: max(8, proxy.size.width * CGFloat(row.usage.total) / CGFloat(maxValue)))
                                    }
                            }
                            .frame(height: 7)
                        }
                    }
                }
            }
        }
        .padding(16)
        .panelBackground()
    }
}

struct TrendPanel: View {
    @EnvironmentObject private var language: LanguageController
    @State private var focusedDayID: Date?
    var days: [DailyUsage]

    private var visibleDays: [DailyUsage] {
        Array(days.suffix(30))
    }

    private var focusedDay: DailyUsage? {
        visibleDays.first { $0.id == focusedDayID } ?? visibleDays.last
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                PanelTitle(title: language.text("趋势", "趨勢", "Trend"), tint: TokenScopePalette.mint)
                Spacer()
                if !days.isEmpty {
                    HStack(spacing: 12) {
                        TrendLegend(color: TokenScopePalette.blue, text: language.text("输入", "輸入", "Input"))
                        TrendLegend(color: TokenScopePalette.mint, text: language.text("缓存", "快取", "Cached"))
                        TrendLegend(color: TokenScopePalette.coral, text: language.text("输出", "輸出", "Output"))
                    }
                }
            }

            if days.isEmpty {
                EmptyState(text: language.text("读取到 Token 后这里会显示每日趋势", "讀取到 Token 後這裡會顯示每日趨勢", "Daily trends appear after token data is found"))
                    .frame(height: 170)
            } else if let focusedDay {
                TrendFocusRow(day: focusedDay)

                let maxValue = max(visibleDays.map { $0.usage.total }.max() ?? 1, 1)
                let labelStride = max(visibleDays.count / 7, 1)
                ZStack(alignment: .bottom) {
                    VStack(spacing: 0) {
                        Divider()
                        Spacer()
                        Divider()
                        Spacer()
                        Divider()
                    }
                    .foregroundStyle(TokenScopePalette.border.opacity(0.72))
                    .padding(.bottom, 17)

                    HStack(alignment: .bottom, spacing: 5) {
                        ForEach(Array(visibleDays.enumerated()), id: \.element.id) { index, day in
                            let isFocused = day.id == focusedDay.id
                            VStack(spacing: 5) {
                                TrendBar(
                                    usage: day.usage,
                                    maxValue: maxValue,
                                    isFocused: isFocused
                                )
                                .frame(height: 116, alignment: .bottom)

                                Text(index % labelStride == 0 || index == visibleDays.count - 1 ? dayLabel(day.day) : "")
                                    .font(.system(size: 9, weight: isFocused ? .black : .bold, design: .rounded))
                                    .foregroundStyle(isFocused ? TokenScopePalette.ink : TokenScopePalette.secondaryInk)
                                    .frame(height: 11)
                            }
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .onHover { isInside in
                                if isInside {
                                    focusedDayID = day.id
                                } else if focusedDayID == day.id {
                                    focusedDayID = nil
                                }
                            }
                            .onTapGesture {
                                focusedDayID = day.id
                            }
                            .help(tooltip(for: day))
                            .accessibilityLabel(tooltip(for: day))
                        }
                    }
                }
                .frame(height: 138)
                .animation(.easeOut(duration: 0.12), value: focusedDayID)
            }
        }
        .padding(16)
        .panelBackground()
    }

    private func tooltip(for day: DailyUsage) -> String {
        [
            shortDate(day.day, language: language.current),
            "\(language.text("总 Token", "總 Token", "Total tokens")): \(formatTokens(day.usage.total))",
            "\(language.text("输入", "輸入", "Input")): \(formatTokens(day.usage.visibleInput))",
            "\(language.text("输出", "輸出", "Output")): \(formatTokens(day.usage.output + day.usage.reasoningOutput))",
            "\(language.text("缓存 Token", "快取 Token", "Cached tokens")): \(formatTokens(day.usage.cachedInput))",
            "\(language.text("缓存命中率", "快取命中率", "Cache hit rate")): \(formatPercent(cacheHitRate(day.usage)))",
            "\(language.text("请求数", "請求數", "Requests")): \(formatCount(day.requestCount))"
        ].joined(separator: "\n")
    }
}

private struct TrendFocusRow: View {
    @EnvironmentObject private var language: LanguageController
    var day: DailyUsage

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(shortDate(day.day, language: language.current))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Text(language.text("每日明细", "每日明細", "Daily detail"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 78, alignment: .leading)

            Divider()
                .frame(height: 34)

            TrendFocusMetric(title: language.text("总 Token", "總 Token", "Total"), value: formatTokens(day.usage.total), tint: TokenScopePalette.ink)
            TrendFocusMetric(title: language.text("输入", "輸入", "Input"), value: formatTokens(day.usage.visibleInput), tint: TokenScopePalette.blue)
            TrendFocusMetric(title: language.text("缓存 Token", "快取 Token", "Cached"), value: formatTokens(day.usage.cachedInput), tint: TokenScopePalette.mint)
            TrendFocusMetric(title: language.text("输出", "輸出", "Output"), value: formatTokens(day.usage.output + day.usage.reasoningOutput), tint: TokenScopePalette.coral)
            TrendFocusMetric(title: language.text("缓存命中率", "快取命中率", "Cache hit"), value: formatPercent(cacheHitRate(day.usage)), tint: Color(hex: "0D8F72"))
            TrendFocusMetric(title: language.text("请求数", "請求數", "Requests"), value: formatCount(day.requestCount), tint: TokenScopePalette.violet)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(TokenScopePalette.surfaceMuted)
        .overlay(alignment: .top) { Divider().foregroundStyle(TokenScopePalette.border) }
        .overlay(alignment: .bottom) { Divider().foregroundStyle(TokenScopePalette.border) }
    }
}

private struct TrendFocusMetric: View {
    var title: String
    var value: String
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TrendLegend: View {
    var color: Color
    var text: String

    var body: some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }
}

private struct TrendBar: View {
    var usage: TokenUsage
    var maxValue: Int
    var isFocused: Bool

    private var barHeight: CGFloat {
        max(8, CGFloat(usage.total) / CGFloat(max(maxValue, 1)) * 112)
    }

    private var cached: Int {
        min(max(usage.cachedInput, 0), max(usage.total, 0))
    }

    private var output: Int {
        min(max(usage.output + usage.reasoningOutput, 0), max(usage.total - cached, 0))
    }

    private var input: Int {
        max(usage.total - cached - output, 0)
    }

    var body: some View {
        let denominator = CGFloat(max(usage.total, 1))
        VStack(spacing: 0) {
            Rectangle()
                .fill(TokenScopePalette.coral)
                .frame(height: barHeight * CGFloat(output) / denominator)
            Rectangle()
                .fill(TokenScopePalette.mint)
                .frame(height: barHeight * CGFloat(cached) / denominator)
            Rectangle()
                .fill(TokenScopePalette.blue)
                .frame(height: barHeight * CGFloat(input) / denominator)
        }
        .frame(maxWidth: .infinity)
        .frame(height: barHeight, alignment: .bottom)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(isFocused ? TokenScopePalette.ink.opacity(0.78) : Color.clear, lineWidth: 1.5)
        }
        .opacity(isFocused ? 1 : 0.64)
        .shadow(color: isFocused ? TokenScopePalette.blue.opacity(0.18) : .clear, radius: 3, y: 1)
        .frame(maxHeight: .infinity, alignment: .bottom)
    }
}

struct ModelPanel: View {
    @EnvironmentObject private var language: LanguageController
    var rows: [UsageBreakdown]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                PanelTitle(title: language.text("模型排行", "模型排行", "Top models"), tint: TokenScopePalette.coral)
                Spacer()
                Text(language.text("输入 / Cache / 输出 / 费用", "輸入 / Cache / 輸出 / 費用", "Input / Cache / Output / Cost"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            if rows.isEmpty {
                EmptyState(text: language.text("暂无模型用量", "暫無模型用量", "No model usage"))
            } else {
                VStack(spacing: 0) {
                    ForEach(rows) { row in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(row.name)
                                    .font(.system(size: 13, weight: .bold))
                                    .lineLimit(1)
                                Text(row.subtitle)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            TokenMiniColumn(title: "I", value: row.usage.input)
                            TokenMiniColumn(title: "C", value: row.usage.cachedInput + row.usage.cacheWrite)
                            TokenMiniColumn(title: "O", value: row.usage.output)
                            Text(formatTokens(row.usage.total))
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .frame(width: 72, alignment: .trailing)
                            Text(row.pricedRequestCount > 0 ? formatCurrency(row.costUSD) : "—")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(TokenScopePalette.amber)
                                .frame(width: 78, alignment: .trailing)
                        }
                        .padding(.vertical, 10)
                        .overlay(alignment: .bottom) {
                            Divider().opacity(row.id == rows.last?.id ? 0 : 1)
                        }
                    }
                }
            }
        }
        .padding(16)
        .panelBackground()
    }
}

struct TokenMiniColumn: View {
    var title: String
    var value: Int

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .black, design: .rounded))
                .foregroundStyle(.secondary)
            Text(formatTokens(value))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(width: 54)
    }
}

struct AgentStrip: View {
    @EnvironmentObject private var language: LanguageController
    var agents: [AgentToolInfo]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(agents) { agent in
                    HStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(statusColor(agent.status).opacity(0.14))
                            Image(systemName: agent.icon)
                                .foregroundStyle(statusColor(agent.status))
                        }
                        .frame(width: 28, height: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(agent.name)
                                .font(.system(size: 12, weight: .bold))
                                .lineLimit(1)
                            Text(language.statusLabel(agent.status))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 48)
                    .background(TokenScopePalette.surfaceMuted, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(TokenScopePalette.border))
                    .help(language.agentNote(agent))
                }
            }
        }
    }
}

struct EmptyState: View {
    var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "chart.bar.doc.horizontal")
            Text(text)
                .lineLimit(2)
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(TokenScopePalette.secondaryInk)
        .frame(maxWidth: .infinity, minHeight: 86)
    }
}

struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(9)
            .background(
                configuration.isPressed ? TokenScopePalette.surfaceMuted : TokenScopePalette.surface,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(TokenScopePalette.border))
    }
}

private extension View {
    func panelBackground() -> some View {
        background(TokenScopePalette.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(TokenScopePalette.border))
            .shadow(color: TokenScopePalette.ink.opacity(0.045), radius: 10, x: 0, y: 4)
    }
}

private func statusColor(_ status: ToolSupportStatus) -> Color {
    switch status {
    case .liveData:
        return TokenScopePalette.mint
    case .detected:
        return TokenScopePalette.blue
    case .preset:
        return TokenScopePalette.secondaryInk
    }
}

func formatTokens(_ value: Int) -> String {
    let absValue = abs(value)
    if absValue >= 1_000_000_000 {
        return String(format: "%.2fB", Double(value) / 1_000_000_000)
    }
    if absValue >= 1_000_000 {
        return String(format: "%.2fM", Double(value) / 1_000_000)
    }
    if absValue >= 1_000 {
        return String(format: "%.1fK", Double(value) / 1_000)
    }
    return "\(value)"
}

func formatCount(_ value: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 0
    return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
}

func formatCurrency(_ value: Double) -> String {
    if value > 0, value < 0.01 {
        return String(format: "$%.4f", value)
    }
    return String(format: "$%.2f", value)
}

private func cacheHitRate(_ usage: TokenUsage) -> Double {
    let cacheableInput = usage.input + usage.cachedInput + usage.cacheWrite
    guard cacheableInput > 0 else { return 0 }
    return Double(usage.cachedInput) / Double(cacheableInput)
}

private func formatPercent(_ value: Double) -> String {
    String(format: "%.1f%%", value * 100)
}

private func shortDate(_ date: Date, language: AppLanguage) -> String {
    let formatter = DateFormatter()
    formatter.locale = language.locale
    formatter.dateFormat = language == .english ? "MMM d" : "M月d日"
    return formatter.string(from: date)
}

private func dayLabel(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "d"
    return formatter.string(from: date)
}

private extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let red = Double((rgb >> 16) & 0xFF) / 255.0
        let green = Double((rgb >> 8) & 0xFF) / 255.0
        let blue = Double(rgb & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}
