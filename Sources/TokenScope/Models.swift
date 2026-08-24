import Foundation

struct TokenUsage: Codable, Hashable {
    var input: Int
    var cachedInput: Int
    var cacheWrite: Int
    var output: Int
    var reasoningOutput: Int
    var total: Int

    static let zero = TokenUsage(input: 0, cachedInput: 0, cacheWrite: 0, output: 0, reasoningOutput: 0, total: 0)

    var visibleInput: Int {
        input + cachedInput + cacheWrite
    }

    var uncachedTotal: Int {
        input + output
    }

    mutating func add(_ other: TokenUsage) {
        input += other.input
        cachedInput += other.cachedInput
        cacheWrite += other.cacheWrite
        output += other.output
        reasoningOutput += other.reasoningOutput
        total += other.total
    }

    func subtracting(_ previous: TokenUsage) -> TokenUsage {
        TokenUsage(
            input: max(0, input - previous.input),
            cachedInput: max(0, cachedInput - previous.cachedInput),
            cacheWrite: max(0, cacheWrite - previous.cacheWrite),
            output: max(0, output - previous.output),
            reasoningOutput: max(0, reasoningOutput - previous.reasoningOutput),
            total: max(0, total - previous.total)
        )
    }
}

struct UsageRecord: Identifiable, Codable, Hashable {
    var id: String
    var timestamp: Date
    var tool: String
    var provider: String
    var model: String
    var usage: TokenUsage
    var costUSD: Double?
    var costBasis: CostBasis?
    var sourcePath: String
}

enum ToolSupportStatus: String, Codable, Hashable {
    case liveData
    case detected
    case preset

    var label: String {
        switch self {
        case .liveData:
            return "有用量"
        case .detected:
            return "已识别"
        case .preset:
            return "预设"
        }
    }
}

struct AgentToolInfo: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var category: String
    var icon: String
    var status: ToolSupportStatus
    var canReadTokens: Bool
    var detectedPaths: [String]
    var note: String
}

struct ProviderPreset: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var category: String
    var icon: String
    var accentHex: String
    var featured: Bool
}

struct UsageSnapshot: Codable {
    var generatedAt: Date
    var records: [UsageRecord]
    var agents: [AgentToolInfo]
    var providers: [ProviderPreset]
    var scannedFiles: Int
    var warnings: [String]

    static let empty = UsageSnapshot(
        generatedAt: Date(),
        records: [],
        agents: [],
        providers: ProviderCatalog.providers,
        scannedFiles: 0,
        warnings: []
    )
}

enum UsagePeriod: String, CaseIterable, Identifiable {
    case today
    case week
    case month
    case all

    var id: String { rawValue }

    var label: String {
        switch self {
        case .today:
            return "今天"
        case .week:
            return "7 天"
        case .month:
            return "30 天"
        case .all:
            return "全部"
        }
    }
}

struct UsageBreakdown: Identifiable {
    var id: String
    var name: String
    var subtitle: String
    var usage: TokenUsage
    var costUSD: Double
    var requestCount: Int
    var pricedRequestCount: Int
}

struct DailyUsage: Identifiable {
    var id: Date { day }
    var day: Date
    var usage: TokenUsage
    var costUSD: Double
    var requestCount: Int
}

struct UsageOverview {
    var total: TokenUsage
    var costUSD: Double
    var requestCount: Int
    var pricedRequestCount: Int
    var exactCostRequestCount: Int
    var estimatedCostRequestCount: Int
    var tools: [UsageBreakdown]
    var providers: [UsageBreakdown]
    var models: [UsageBreakdown]
    var days: [DailyUsage]
}

extension UsageSnapshot {
    func overview(period: UsagePeriod, query: String = "") -> UsageOverview {
        let calendar = Calendar.current
        let now = Date()
        let lowerQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let filtered = records.filter { record in
            let inPeriod: Bool
            switch period {
            case .today:
                inPeriod = calendar.isDate(record.timestamp, inSameDayAs: now)
            case .week:
                inPeriod = record.timestamp >= calendar.date(byAdding: .day, value: -7, to: now)!
            case .month:
                inPeriod = record.timestamp >= calendar.date(byAdding: .day, value: -30, to: now)!
            case .all:
                inPeriod = true
            }

            guard inPeriod else { return false }
            guard !lowerQuery.isEmpty else { return true }
            return record.tool.lowercased().contains(lowerQuery)
                || record.provider.lowercased().contains(lowerQuery)
                || record.model.lowercased().contains(lowerQuery)
        }

        var total = TokenUsage.zero
        var cost = 0.0
        struct Accumulator {
            var subtitle: String
            var usage: TokenUsage = .zero
            var costUSD: Double = 0
            var requestCount: Int = 0
            var pricedRequestCount: Int = 0
        }

        var exactCostRequestCount = 0
        var estimatedCostRequestCount = 0
        var byTool: [String: Accumulator] = [:]
        var byProvider: [String: Accumulator] = [:]
        var byModel: [String: Accumulator] = [:]
        var byDay: [Date: Accumulator] = [:]

        func append(_ record: UsageRecord, subtitle: String, to accumulator: inout Accumulator) {
            accumulator.subtitle = subtitle
            accumulator.usage.add(record.usage)
            accumulator.requestCount += 1
            if let recordCost = record.costUSD {
                accumulator.costUSD += recordCost
                accumulator.pricedRequestCount += 1
            }
        }

        for record in filtered {
            total.add(record.usage)
            if let recordCost = record.costUSD {
                cost += recordCost
                if record.costBasis == .reported {
                    exactCostRequestCount += 1
                } else {
                    estimatedCostRequestCount += 1
                }
            }

            var tool = byTool[record.tool] ?? Accumulator(subtitle: "Agent")
            append(record, subtitle: "Agent", to: &tool)
            byTool[record.tool] = tool

            var provider = byProvider[record.provider] ?? Accumulator(subtitle: "Provider")
            append(record, subtitle: "Provider", to: &provider)
            byProvider[record.provider] = provider

            let modelSubtitle = "\(record.provider) / \(record.tool)"
            var model = byModel[record.model] ?? Accumulator(subtitle: modelSubtitle)
            append(record, subtitle: modelSubtitle, to: &model)
            byModel[record.model] = model

            let day = calendar.startOfDay(for: record.timestamp)
            var daily = byDay[day] ?? Accumulator(subtitle: "")
            append(record, subtitle: "", to: &daily)
            byDay[day] = daily
        }

        return UsageOverview(
            total: total,
            costUSD: cost,
            requestCount: filtered.count,
            pricedRequestCount: exactCostRequestCount + estimatedCostRequestCount,
            exactCostRequestCount: exactCostRequestCount,
            estimatedCostRequestCount: estimatedCostRequestCount,
            tools: byTool.map { UsageBreakdown(id: $0.key, name: $0.key, subtitle: $0.value.subtitle, usage: $0.value.usage, costUSD: $0.value.costUSD, requestCount: $0.value.requestCount, pricedRequestCount: $0.value.pricedRequestCount) }
                .sorted { $0.usage.total > $1.usage.total },
            providers: byProvider.map { UsageBreakdown(id: $0.key, name: $0.key, subtitle: $0.value.subtitle, usage: $0.value.usage, costUSD: $0.value.costUSD, requestCount: $0.value.requestCount, pricedRequestCount: $0.value.pricedRequestCount) }
                .sorted { $0.usage.total > $1.usage.total },
            models: byModel.map { UsageBreakdown(id: $0.key, name: $0.key, subtitle: $0.value.subtitle, usage: $0.value.usage, costUSD: $0.value.costUSD, requestCount: $0.value.requestCount, pricedRequestCount: $0.value.pricedRequestCount) }
                .sorted { $0.usage.total > $1.usage.total },
            days: byDay.map { DailyUsage(day: $0.key, usage: $0.value.usage, costUSD: $0.value.costUSD, requestCount: $0.value.requestCount) }
                .sorted { $0.day < $1.day }
        )
    }
}
