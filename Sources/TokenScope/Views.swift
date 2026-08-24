import AppKit
import SwiftUI

struct TokenScopeRootView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var launchAtLogin: LaunchAtLoginController
    @State private var period: UsagePeriod = .week
    @State private var query = ""

    var overview: UsageOverview {
        store.snapshot.overview(period: period, query: query)
    }

    var todayOverview: UsageOverview {
        store.snapshot.overview(period: .today)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(hex: "F7FAFC"),
                    Color(hex: "FFF7ED")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: 16) {
                        DailyReminder(overview: todayOverview, launchAtLogin: launchAtLogin)
                        summaryBand
                        contentGrid
                        providerSection
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 22)
                }
            }
        }
        .frame(minWidth: 960, minHeight: 660)
        .alert("TokenScope", isPresented: Binding(
            get: { launchAtLogin.errorMessage != nil },
            set: { if !$0 { launchAtLogin.errorMessage = nil } }
        )) {
            Button("好") {
                launchAtLogin.errorMessage = nil
            }
        } message: {
            Text(launchAtLogin.errorMessage ?? "")
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("TokenScope")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text("本机 AI Agent 用量与 API 等值成本")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("", selection: $period) {
                ForEach(UsagePeriod.allCases) { item in
                    Text(item.label).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 240)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("搜索模型、Provider、Agent", text: $query)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 12)
            .frame(width: 230, height: 36)
            .background(.white.opacity(0.74), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.black.opacity(0.06)))

            Button {
                store.refresh(force: true)
            } label: {
                Image(systemName: store.isScanning ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(IconButtonStyle())
            .help("重新扫描")
            .disabled(store.isScanning)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(IconButtonStyle())
            .help("退出")
        }
        .padding(22)
    }

    private var summaryBand: some View {
        HStack(spacing: 12) {
            HeroMetricCard(
                title: "总 Token",
                value: formatTokens(overview.total.total),
                subtitle: "扫描 \(store.snapshot.scannedFiles) 个本地日志文件",
                icon: "sum",
                tint: Color(hex: "0A84FF")
            )

            MetricTile(title: "总成本", value: formatCurrency(overview.costUSD), footnote: costFootnote, icon: "dollarsign.circle.fill", tint: Color(hex: "D97706"))
            MetricTile(title: "总请求数", value: formatCount(overview.requestCount), footnote: "产生 Token 的响应", icon: "arrow.up.arrow.down.circle.fill", tint: Color(hex: "6366F1"))
            MetricTile(title: "输入", value: formatTokens(overview.total.visibleInput), footnote: "含 Cache", icon: "tray.and.arrow.down.fill", tint: Color(hex: "10B981"))
            MetricTile(title: "输出", value: formatTokens(overview.total.output), footnote: "含 Reasoning", icon: "tray.and.arrow.up.fill", tint: Color(hex: "E85D3F"))
        }
    }

    private var costFootnote: String {
        guard overview.requestCount > 0 else { return "暂无请求" }
        if overview.pricedRequestCount == overview.requestCount {
            return overview.exactCostRequestCount > 0 ? "日志金额 + API 预估" : "API 等值预估"
        }
        return "\(overview.pricedRequestCount)/\(overview.requestCount) 次已计价"
    }

    private var contentGrid: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 16) {
                BreakdownPanel(title: "Agent 用量", rows: Array(overview.tools.prefix(8)), emptyText: "还没有读到可统计的 Agent token")
                BreakdownPanel(title: "Provider 用量", rows: Array(overview.providers.prefix(8)), emptyText: "Provider 会在读取到模型后自动归类")
            }
            .frame(width: 330)

            VStack(spacing: 16) {
                TrendPanel(days: overview.days)
                ModelPanel(rows: Array(overview.models.prefix(10)))
            }
        }
    }

    private var providerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("供应商与 Agent 覆盖")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                Spacer()
                Text("真实用量优先，未开放 token 日志的工具仅做识别")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            AgentStrip(agents: store.snapshot.agents)

            let filteredProviders = store.snapshot.providers.filter { provider in
                query.isEmpty
                    || provider.name.localizedCaseInsensitiveContains(query)
                    || provider.category.localizedCaseInsensitiveContains(query)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(filteredProviders) { provider in
                    ProviderPill(provider: provider)
                }
            }
        }
        .padding(16)
        .panelBackground()
    }
}

struct DailyReminder: View {
    var overview: UsageOverview
    @ObservedObject var launchAtLogin: LaunchAtLoginController

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(hex: "F59E0B").opacity(0.15))
                Image(systemName: reminderIcon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color(hex: "D97706"))
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text(reminderText)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Text("今日 \(formatCount(overview.requestCount)) 次请求 · \(formatTokens(overview.total.total)) Token · \(formatCurrency(overview.costUSD)) 预估成本")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Toggle("开机自启", isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.setEnabled($0) }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .font(.system(size: 11, weight: .bold))
                .disabled(!launchAtLogin.isInstalledInApplications && !launchAtLogin.isEnabled)

                if launchAtLogin.requiresApproval {
                    Button("需要在系统设置中批准") {
                        launchAtLogin.openSystemSettings()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(hex: "D97706"))
                } else if !launchAtLogin.isInstalledInApplications {
                    Text("拖入“应用程序”后可开启")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(hex: "D97706"))
                } else {
                    Text("后台常驻 · 数据仅保留在本机")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 62)
        .background(Color(hex: "FFF7E8").opacity(0.92), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "F59E0B").opacity(0.20)))
    }

    private var reminderIcon: String {
        overview.requestCount >= 100 ? "figure.cooldown" : "cup.and.saucer.fill"
    }

    private var reminderText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if overview.requestCount == 0 {
            return hour < 12 ? "早上好，今天慢慢来，先做好最重要的一件事。" : "给自己留一点从容，准备好了再开始。"
        }
        if hour >= 18 {
            return "今天辛苦了，收尾时也记得照顾好自己。"
        }
        if overview.requestCount >= 100 {
            return "今天完成了很多工作，辛苦了，先伸展一下再继续。"
        }
        if overview.requestCount >= 30 {
            return "进展很扎实，辛苦了，记得抬头放松一下眼睛。"
        }
        return "已经迈出了今天的步子，辛苦了，记得喝口水。"
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
                    .fill(tint.opacity(0.14))
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(tint)
            }
            .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 31, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 104)
        .background(
            LinearGradient(colors: [.white.opacity(0.92), tint.opacity(0.10)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.black.opacity(0.06)))
    }
}

struct MetricTile: View {
    var title: String
    var value: String
    var footnote: String
    var icon: String
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                Spacer()
            }
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                Text(footnote)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .frame(width: 132)
        .frame(minHeight: 104)
        .panelBackground()
    }
}

struct BreakdownPanel: View {
    var title: String
    var rows: [UsageBreakdown]
    var emptyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 17, weight: .bold, design: .rounded))

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
                                    Text(row.pricedRequestCount > 0 ? formatCurrency(row.costUSD) : "未计价")
                                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                            }

                            GeometryReader { proxy in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.black.opacity(0.06))
                                    .overlay(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color(hex: "0A84FF"))
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
    var days: [DailyUsage]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("趋势")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                Spacer()
                Text(days.isEmpty ? "暂无数据" : "\(days.count) 天")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            if days.isEmpty {
                EmptyState(text: "读取到 token 后这里会显示每日趋势")
                    .frame(height: 170)
            } else {
                let maxValue = max(days.map { $0.usage.total }.max() ?? 1, 1)
                HStack(alignment: .bottom, spacing: 7) {
                    ForEach(days.suffix(30)) { day in
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(
                                    LinearGradient(colors: [Color(hex: "0A84FF"), Color(hex: "10B981")], startPoint: .top, endPoint: .bottom)
                                )
                                .frame(height: max(8, CGFloat(day.usage.total) / CGFloat(maxValue) * 150))
                                .help("\(shortDate(day.day)): \(formatTokens(day.usage.total)) · \(day.requestCount) 次 · \(formatCurrency(day.costUSD))")
                            Text(dayLabel(day.day))
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 184)
            }
        }
        .padding(16)
        .panelBackground()
    }
}

struct ModelPanel: View {
    var rows: [UsageBreakdown]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("模型排行")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                Spacer()
                Text("Input / Cache / Output / 费用")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            if rows.isEmpty {
                EmptyState(text: "暂无模型用量")
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
                                .foregroundStyle(Color(hex: "D97706"))
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
                            Text(agent.status.label)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 48)
                    .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.black.opacity(0.06)))
                    .help(agent.note)
                }
            }
        }
    }
}

struct ProviderPill: View {
    var provider: ProviderPreset

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(hex: provider.accentHex).opacity(0.13))
                Image(systemName: provider.icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(hex: provider.accentHex))
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(provider.name)
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)
                Text(provider.category)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if provider.featured {
                Image(systemName: "star.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(hex: "F59E0B"))
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 54)
        .background(.white.opacity(0.68), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.black.opacity(0.055)))
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
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, minHeight: 86)
    }
}

struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(9)
            .background(.white.opacity(configuration.isPressed ? 0.48 : 0.74), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.black.opacity(0.06)))
    }
}

private extension View {
    func panelBackground() -> some View {
        background(.white.opacity(0.76), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.black.opacity(0.06)))
            .shadow(color: .black.opacity(0.05), radius: 16, x: 0, y: 8)
    }
}

private func statusColor(_ status: ToolSupportStatus) -> Color {
    switch status {
    case .liveData:
        return Color(hex: "10B981")
    case .detected:
        return Color(hex: "0A84FF")
    case .preset:
        return Color(hex: "6B7280")
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

private func shortDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "M月d日"
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
