import Foundation

final class UsageScanner {
    private let fileManager = FileManager.default
    private let homeURL = FileManager.default.homeDirectoryForCurrentUser

    func scan() -> UsageSnapshot {
        var warnings: [String] = []
        var scannedFiles = 0
        var records: [UsageRecord] = []
        let pricing = PricingCatalog.load()

        let claude = scanClaudeCode(pricing: pricing)
        records.append(contentsOf: claude.records)
        scannedFiles += claude.scannedFiles
        warnings.append(contentsOf: claude.warnings)

        let codex = scanCodex(pricing: pricing)
        records.append(contentsOf: codex.records)
        scannedFiles += codex.scannedFiles
        warnings.append(contentsOf: codex.warnings)

        let agents = discoverAgents(records: records)

        return UsageSnapshot(
            generatedAt: Date(),
            records: records.sorted { $0.timestamp > $1.timestamp },
            agents: agents,
            providers: ProviderCatalog.providers,
            scannedFiles: scannedFiles,
            warnings: warnings
        )
    }

    private func scanClaudeCode(pricing: PricingCatalog) -> (records: [UsageRecord], scannedFiles: Int, warnings: [String]) {
        let root = expandHome("~/.claude/projects")
        let files = jsonlFiles(under: root)
        var records: [UsageRecord] = []
        var warnings: [String] = []

        for file in files {
            var seenMessageIDs = Set<String>()
            readJSONLines(file) { object in
                guard object.string("type") == "assistant",
                      let message = object.dictionary("message"),
                      let usageObject = message.dictionary("usage") else {
                    return
                }

                let messageID = message.string("id") ?? object.string("uuid") ?? UUID().uuidString
                guard !seenMessageIDs.contains(messageID) else { return }
                seenMessageIDs.insert(messageID)

                let timestamp = self.parseDate(object.string("timestamp")) ?? self.fileModificationDate(file) ?? Date()
                let model = message.string("model") ?? "Claude Code"
                let provider = ProviderCatalog.providerName(for: model, fallback: "Anthropic")

                let cacheCreation = usageObject.int("cache_creation_input_tokens")
                    + (usageObject.dictionary("cache_creation")?.int("ephemeral_1h_input_tokens") ?? 0)
                    + (usageObject.dictionary("cache_creation")?.int("ephemeral_5m_input_tokens") ?? 0)

                let usage = TokenUsage(
                    input: usageObject.int("input_tokens"),
                    cachedInput: usageObject.int("cache_read_input_tokens"),
                    cacheWrite: cacheCreation,
                    output: usageObject.int("output_tokens"),
                    reasoningOutput: 0,
                    total: usageObject.int("input_tokens") + usageObject.int("cache_read_input_tokens") + cacheCreation + usageObject.int("output_tokens")
                )

                guard usage.total > 0 else { return }
                let reportedCost = object.double("costUSD").flatMap { $0 > 0 ? $0 : nil }
                let quote = reportedCost == nil ? pricing.quote(model: model, usage: usage) : nil

                records.append(
                    UsageRecord(
                        id: "claude:\(file.path):\(messageID)",
                        timestamp: timestamp,
                        tool: "Claude Code",
                        provider: provider,
                        model: model,
                        usage: usage,
                        costUSD: reportedCost ?? quote?.amountUSD,
                        costBasis: reportedCost == nil ? quote?.basis : .reported,
                        sourcePath: file.path
                    )
                )
            } onError: { error in
                warnings.append("Claude Code: \(file.lastPathComponent) 读取失败: \(error.localizedDescription)")
            }
        }

        return (records, files.count, warnings)
    }

    private func scanCodex(pricing: PricingCatalog) -> (records: [UsageRecord], scannedFiles: Int, warnings: [String]) {
        let root = expandHome("~/.codex/sessions")
        let files = jsonlFiles(under: root)
        let threadMetadata = loadCodexThreadMetadata()
        var records: [UsageRecord] = []
        var warnings: [String] = []

        for file in files {
            var sessionID = file.deletingPathExtension().lastPathComponent
            var modelProvider = "openai"
            var model = "Codex"
            var previousTotal = TokenUsage.zero

            readJSONLines(file) { object in
                if object.string("type") == "session_meta", let payload = object.dictionary("payload") {
                    if let id = payload.string("id") ?? payload.string("session_id") {
                        sessionID = id
                    }
                    if let provider = payload.string("model_provider") {
                        modelProvider = provider
                    }
                    if let meta = threadMetadata[sessionID] {
                        modelProvider = meta.provider.isEmpty ? modelProvider : meta.provider
                        model = meta.model.isEmpty ? model : meta.model
                    }
                    return
                }

                guard object.string("type") == "event_msg",
                      let payload = object.dictionary("payload"),
                      payload.string("type") == "token_count",
                      let info = payload.dictionary("info"),
                      let totalObject = info.dictionary("total_token_usage") else {
                    return
                }

                let cachedInput = totalObject.int("cached_input_tokens")
                let cacheWrite = totalObject.int("cache_write_input_tokens")
                let total = TokenUsage(
                    input: max(0, totalObject.int("input_tokens") - cachedInput - cacheWrite),
                    cachedInput: cachedInput,
                    cacheWrite: cacheWrite,
                    output: totalObject.int("output_tokens"),
                    reasoningOutput: totalObject.int("reasoning_output_tokens"),
                    total: totalObject.int("total_tokens")
                )

                guard total.total > previousTotal.total else { return }
                let delta = total.subtracting(previousTotal)
                previousTotal = total
                guard delta.total > 0 else { return }

                let timestamp = self.parseDate(object.string("timestamp")) ?? self.fileModificationDate(file) ?? Date()
                let provider = self.normalizeProvider(modelProvider)
                let quote = pricing.quote(model: model, usage: delta)

                records.append(
                    UsageRecord(
                        id: "codex:\(sessionID):\(timestamp.timeIntervalSince1970):\(total.total)",
                        timestamp: timestamp,
                        tool: "Codex",
                        provider: provider,
                        model: model,
                        usage: delta,
                        costUSD: quote?.amountUSD,
                        costBasis: quote?.basis,
                        sourcePath: file.path
                    )
                )
            } onError: { error in
                warnings.append("Codex: \(file.lastPathComponent) 读取失败: \(error.localizedDescription)")
            }
        }

        return (records, files.count, warnings)
    }

    private func discoverAgents(records: [UsageRecord]) -> [AgentToolInfo] {
        let totalsByTool = Dictionary(grouping: records, by: \.tool).mapValues { rows in
            rows.reduce(0) { $0 + $1.usage.total }
        }

        return ProviderCatalog.agentProbes.map { probe in
            let detected = probe.paths.map(expandHome).filter { fileManager.fileExists(atPath: $0.path) }
            let total = totalsByTool[probe.name] ?? (probe.id == "codex" ? totalsByTool["Codex"] ?? 0 : 0)
            let status: ToolSupportStatus
            if total > 0 {
                status = .liveData
            } else if !detected.isEmpty {
                status = .detected
            } else {
                status = .preset
            }

            return AgentToolInfo(
                id: probe.id,
                name: probe.name,
                category: probe.category,
                icon: probe.icon,
                status: status,
                canReadTokens: probe.canReadTokens,
                detectedPaths: detected.map(\.path),
                note: probe.note
            )
        }
    }

    private struct CodexThreadMeta {
        var provider: String
        var model: String
    }

    private func loadCodexThreadMetadata() -> [String: CodexThreadMeta] {
        let db = expandHome("~/.codex/state_5.sqlite")
        guard fileManager.fileExists(atPath: db.path) else { return [:] }

        let query = "select id, coalesce(model_provider,''), coalesce(model,'') from threads;"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = ["-readonly", "-separator", "\t", db.path, query]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return [:]
        }

        guard process.terminationStatus == 0 else { return [:] }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: data, as: UTF8.self)
        var result: [String: CodexThreadMeta] = [:]

        for line in output.split(separator: "\n") {
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard parts.count >= 3 else { continue }
            result[parts[0]] = CodexThreadMeta(provider: parts[1], model: parts[2])
        }

        return result
    }

    private func jsonlFiles(under root: URL) -> [URL] {
        guard fileManager.fileExists(atPath: root.path) else { return [] }
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
            options: [.skipsPackageDescendants]
        ) else {
            return []
        }

        var result: [URL] = []
        for case let file as URL in enumerator where file.pathExtension == "jsonl" {
            result.append(file)
        }
        return result
    }

    private func readJSONLines(_ file: URL, handle: @escaping ([String: Any]) -> Void, onError: @escaping (Error) -> Void) {
        do {
            let data = try Data(contentsOf: file, options: [.mappedIfSafe])
            let text = String(decoding: data, as: UTF8.self)
            text.enumerateLines { line, _ in
                guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      let lineData = line.data(using: .utf8),
                      let object = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                    return
                }
                handle(object)
            }
        } catch {
            onError(error)
        }
    }

    private func expandHome(_ path: String) -> URL {
        if path == "~" {
            return homeURL
        }
        if path.hasPrefix("~/") {
            return homeURL.appendingPathComponent(String(path.dropFirst(2)))
        }
        return URL(fileURLWithPath: path)
    }

    private func fileModificationDate(_ url: URL) -> Date? {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }

    private func normalizeProvider(_ provider: String) -> String {
        switch provider.lowercased() {
        case "openai":
            return "OpenAI"
        case "anthropic":
            return "Anthropic"
        default:
            return provider.isEmpty ? "Unknown" : provider
        }
    }

    private func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) {
            return date
        }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: value)
    }
}

private extension Dictionary where Key == String, Value == Any {
    func dictionary(_ key: String) -> [String: Any]? {
        self[key] as? [String: Any]
    }

    func string(_ key: String) -> String? {
        self[key] as? String
    }

    func int(_ key: String) -> Int {
        if let value = self[key] as? Int {
            return value
        }
        if let value = self[key] as? NSNumber {
            return value.intValue
        }
        if let value = self[key] as? String, let parsed = Int(value) {
            return parsed
        }
        return 0
    }

    func double(_ key: String) -> Double? {
        if let value = self[key] as? Double {
            return value
        }
        if let value = self[key] as? NSNumber {
            return value.doubleValue
        }
        if let value = self[key] as? String {
            return Double(value)
        }
        return nil
    }
}
