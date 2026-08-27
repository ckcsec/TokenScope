import Foundation

final class UsageScanner: @unchecked Sendable {
    private let fileManager = FileManager.default

    func scan(locations: UsageSourceLocations, previousSnapshot: UsageSnapshot? = nil) -> UsageSnapshot {
        var activeSecurityScopes: [URL] = []
        for url in locations.securityScopedRoots where url.startAccessingSecurityScopedResource() {
            activeSecurityScopes.append(url)
        }
        defer {
            activeSecurityScopes.forEach { $0.stopAccessingSecurityScopedResource() }
        }

        var warnings: [String] = []
        var scannedFiles = 0
        var records: [UsageRecord] = []
        let pricing = PricingCatalog.load(ccSwitchDatabaseURL: locations.ccSwitchDatabaseURL)
        let previousRecordsByPath = Dictionary(grouping: previousSnapshot?.records ?? [], by: \.sourcePath)
        let previousGeneratedAt = previousSnapshot?.generatedAt

        if let root = locations.claudeProjectsURL {
            let claude = scanClaudeCode(
                at: root,
                pricing: pricing,
                previousRecordsByPath: previousRecordsByPath,
                previousGeneratedAt: previousGeneratedAt
            )
            records.append(contentsOf: claude.records)
            scannedFiles += claude.scannedFiles
            warnings.append(contentsOf: claude.warnings)
        }

        if let root = locations.codexSessionsURL {
            let codex = scanCodex(
                at: root,
                databaseURL: locations.codexDatabaseURL,
                pricing: pricing,
                previousRecordsByPath: previousRecordsByPath,
                previousGeneratedAt: previousGeneratedAt
            )
            records.append(contentsOf: codex.records)
            scannedFiles += codex.scannedFiles
            warnings.append(contentsOf: codex.warnings)
        }

        if let databaseURL = locations.cursorDatabaseURL {
            let cursor = scanCursor(databaseURL: databaseURL)
            records.append(contentsOf: cursor.records)
            scannedFiles += cursor.scannedFiles
            warnings.append(contentsOf: cursor.warnings)
        }

        if let root = locations.grokSessionsURL {
            let grok = scanGrok(at: root, pricing: pricing)
            records.append(contentsOf: grok.records)
            scannedFiles += grok.scannedFiles
            warnings.append(contentsOf: grok.warnings)
        }

        if let databaseURL = locations.zcodeDatabaseURL {
            let zcode = scanZCode(databaseURL: databaseURL, pricing: pricing)
            records.append(contentsOf: zcode.records)
            scannedFiles += zcode.scannedFiles
            warnings.append(contentsOf: zcode.warnings)
        }

        return UsageSnapshot(
            generatedAt: Date(),
            records: records.sorted { $0.timestamp > $1.timestamp },
            agents: discoverAgents(records: records, locations: locations),
            providers: ProviderCatalog.providers,
            scannedFiles: scannedFiles,
            warnings: warnings
        )
    }

    private func scanClaudeCode(
        at root: URL,
        pricing: PricingCatalog,
        previousRecordsByPath: [String: [UsageRecord]],
        previousGeneratedAt: Date?
    ) -> (records: [UsageRecord], scannedFiles: Int, warnings: [String]) {
        let files = jsonlFiles(under: root)
        var records: [UsageRecord] = []
        var warnings: [String] = []

        for file in files {
            if let reused = reusableRecords(
                for: file,
                previousRecordsByPath: previousRecordsByPath,
                previousGeneratedAt: previousGeneratedAt
            ) {
                records.append(contentsOf: reused)
                continue
            }
            var seenMessageIDs = Set<String>()
            readJSONLines(file) { object in
                guard object.string("type") == "assistant",
                      let message = object.dictionary("message"),
                      let usageObject = message.dictionary("usage") else {
                    return
                }

                let messageID = message.string("id") ?? object.string("uuid") ?? UUID().uuidString
                guard seenMessageIDs.insert(messageID).inserted else { return }

                let timestamp = self.parseDate(object.string("timestamp")) ?? Date()
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

    private func scanCodex(
        at root: URL,
        databaseURL: URL?,
        pricing: PricingCatalog,
        previousRecordsByPath: [String: [UsageRecord]],
        previousGeneratedAt: Date?
    ) -> (records: [UsageRecord], scannedFiles: Int, warnings: [String]) {
        let files = jsonlFiles(under: root)
        let threadMetadata = loadCodexThreadMetadata(databaseURL: databaseURL)
        var records: [UsageRecord] = []
        var warnings: [String] = []

        for file in files {
            if let reused = reusableRecords(
                for: file,
                previousRecordsByPath: previousRecordsByPath,
                previousGeneratedAt: previousGeneratedAt
            ) {
                records.append(contentsOf: reused)
                continue
            }
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

                let timestamp = self.parseDate(object.string("timestamp")) ?? Date()
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

    private func reusableRecords(
        for file: URL,
        previousRecordsByPath: [String: [UsageRecord]],
        previousGeneratedAt: Date?
    ) -> [UsageRecord]? {
        guard let previousGeneratedAt,
              let records = previousRecordsByPath[file.path],
              !records.isEmpty,
              let values = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
              let modificationDate = values.contentModificationDate,
              modificationDate <= previousGeneratedAt else {
            return nil
        }
        return records
    }

    private func scanCursor(
        databaseURL: URL
    ) -> (records: [UsageRecord], scannedFiles: Int, warnings: [String]) {
        guard fileManager.fileExists(atPath: databaseURL.path) else { return ([], 0, []) }

        // Cursor stores one type=1 bubble for each user-initiated Agent request.
        let query = """
        select key,
               coalesce(json_extract(cast(value as text), '$.createdAt'), ''),
               coalesce(json_extract(cast(value as text), '$.modelInfo.modelName'), ''),
               coalesce(json_extract(cast(value as text), '$.contextWindowStatusAtCreation.tokensUsed'), 0)
        from cursorDiskKV
        where key like 'bubbleId:%'
          and json_valid(cast(value as text))
          and json_extract(cast(value as text), '$.type') = 1;
        """

        let rows = SQLiteReader.rows(at: databaseURL, query: query, columnCount: 4)
        let records = rows.compactMap { values -> UsageRecord? in
            guard values.count == 4, let timestamp = parseDate(values[1]) else { return nil }
            let rawModel = values[2].trimmingCharacters(in: .whitespacesAndNewlines)
            let model = rawModel.isEmpty || rawModel == "default" ? "Cursor Auto" : rawModel
            let contextTokens = max(0, Int(values[3]) ?? 0)
            let usage = TokenUsage(
                input: contextTokens,
                cachedInput: 0,
                cacheWrite: 0,
                output: 0,
                reasoningOutput: 0,
                total: contextTokens
            )

            return UsageRecord(
                id: "cursor:\(values[0])",
                timestamp: timestamp,
                tool: "Cursor",
                provider: ProviderCatalog.providerName(for: model, fallback: "Cursor"),
                model: model,
                usage: usage,
                costUSD: nil,
                costBasis: nil,
                sourcePath: databaseURL.path
            )
        }

        return (records, 1, [])
    }

    private func scanGrok(
        at root: URL,
        pricing: PricingCatalog
    ) -> (records: [UsageRecord], scannedFiles: Int, warnings: [String]) {
        guard fileManager.fileExists(atPath: root.path) else { return ([], 0, []) }

        let sessionFiles = namedFiles(
            ["updates.jsonl", "chat_history.jsonl", "signals.json", "summary.json"],
            under: root
        )
        let sessionDirectories = Set(sessionFiles.map { $0.deletingLastPathComponent() })
        var records: [UsageRecord] = []
        var scannedFiles = 0
        var warnings: [String] = []

        for directory in sessionDirectories.sorted(by: { $0.path < $1.path }) {
            let sessionID = directory.lastPathComponent
            let summaryURL = directory.appendingPathComponent("summary.json")
            let summary = readJSONObject(summaryURL)
            if summary != nil { scannedFiles += 1 }

            let defaultModel = summary.flatMap {
                firstString(in: $0, keys: ["model", "model_id", "modelId", "primaryModelId"])
            } ?? "Grok Build"
            let fallbackDate = summary.flatMap { firstDate(in: $0) }
                ?? ((try? directory.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date())
            var sessionRecords: [UsageRecord] = []
            var seenRecordIDs = Set<String>()

            for fileName in ["updates.jsonl", "chat_history.jsonl"] where sessionRecords.isEmpty {
                let file = directory.appendingPathComponent(fileName)
                guard fileManager.fileExists(atPath: file.path) else { continue }
                scannedFiles += 1
                var eventIndex = 0
                readJSONLines(file) { object in
                    eventIndex += 1
                    for record in self.grokRecords(
                        from: object,
                        sessionID: sessionID,
                        eventIndex: eventIndex,
                        defaultModel: defaultModel,
                        fallbackDate: fallbackDate,
                        sourcePath: file.path,
                        pricing: pricing
                    ) where seenRecordIDs.insert(record.id).inserted {
                        sessionRecords.append(record)
                    }
                } onError: { error in
                    warnings.append("Grok Build: \(file.lastPathComponent) 读取失败: \(error.localizedDescription)")
                }
            }

            if sessionRecords.isEmpty {
                let signalsURL = directory.appendingPathComponent("signals.json")
                if let signals = readJSONObject(signalsURL) {
                    scannedFiles += 1
                    sessionRecords.append(contentsOf: grokRecords(
                        from: signals,
                        sessionID: sessionID,
                        eventIndex: 0,
                        defaultModel: defaultModel,
                        fallbackDate: fallbackDate,
                        sourcePath: signalsURL.path,
                        pricing: pricing
                    ))
                }
            }

            records.append(contentsOf: sessionRecords)
        }

        return (records, scannedFiles, warnings)
    }

    private func grokRecords(
        from object: [String: Any],
        sessionID: String,
        eventIndex: Int,
        defaultModel: String,
        fallbackDate: Date,
        sourcePath: String,
        pricing: PricingCatalog
    ) -> [UsageRecord] {
        let timestamp = firstDate(in: object) ?? fallbackDate
        let eventID = firstString(
            in: object,
            keys: ["messageId", "message_id", "requestId", "request_id", "eventId", "event_id", "id"]
        ) ?? "event-\(eventIndex)"

        if let modelUsage = firstDictionary(in: object, keys: ["modelUsage", "model_usage"]) {
            let parsed = modelUsage.compactMap { model, value -> UsageRecord? in
                guard let usageObject = value as? [String: Any],
                      let usage = grokUsage(from: usageObject) else { return nil }
                let reportedCost = reportedGrokCost(in: usageObject)
                    ?? (modelUsage.count == 1 ? reportedGrokCost(in: object) : nil)
                let quote = reportedCost == nil ? pricing.quote(model: model, usage: usage) : nil
                let calls = usageObject.firstInt(["modelCalls", "model_calls", "requestCount", "request_count", "calls"])

                return UsageRecord(
                    id: "grok:\(sessionID):\(eventID):\(model)",
                    timestamp: timestamp,
                    tool: "Grok Build",
                    provider: "xAI",
                    model: model,
                    usage: usage,
                    costUSD: reportedCost ?? quote?.amountUSD,
                    costBasis: reportedCost == nil ? quote?.basis : .reported,
                    sourcePath: sourcePath,
                    requestCount: calls.flatMap { $0 > 0 ? $0 : nil }
                )
            }
            if !parsed.isEmpty { return parsed }
        }

        guard let usageObject = firstUsageDictionary(in: object),
              let usage = grokUsage(from: usageObject) else { return [] }
        let model = firstString(in: object, keys: ["model", "model_id", "modelId", "primaryModelId"])
            ?? defaultModel
        let reportedCost = reportedGrokCost(in: object) ?? reportedGrokCost(in: usageObject)
        let quote = reportedCost == nil ? pricing.quote(model: model, usage: usage) : nil
        let calls = object.firstInt(["num_turns", "numTurns", "turn_count", "turnCount", "successes", "assistantMessageCount"])

        return [UsageRecord(
            id: "grok:\(sessionID):\(eventID):\(model)",
            timestamp: timestamp,
            tool: "Grok Build",
            provider: "xAI",
            model: model,
            usage: usage,
            costUSD: reportedCost ?? quote?.amountUSD,
            costBasis: reportedCost == nil ? quote?.basis : .reported,
            sourcePath: sourcePath,
            requestCount: calls.flatMap { $0 > 0 ? $0 : nil }
        )]
    }

    private func grokUsage(from object: [String: Any]) -> TokenUsage? {
        let input = object.firstInt(["input_tokens", "inputTokens", "prompt_tokens", "promptTokens"]) ?? 0
        let cacheRead = object.firstInt([
            "cache_read_input_tokens", "cacheReadInputTokens", "cache_read_tokens", "cacheReadTokens", "cached_tokens", "cachedTokens"
        ]) ?? 0
        let cacheWrite = object.firstInt([
            "cache_creation_input_tokens", "cacheCreationInputTokens", "cache_write_input_tokens", "cacheWriteInputTokens"
        ]) ?? 0
        let output = object.firstInt(["output_tokens", "outputTokens", "completion_tokens", "completionTokens"]) ?? 0
        let total = object.firstInt(["total_tokens", "totalTokens"])
            ?? (input + cacheRead + cacheWrite + output)
        guard total > 0 else { return nil }

        // Grok Build's output_tokens already includes reasoning tokens.
        return TokenUsage(
            input: max(0, input),
            cachedInput: max(0, cacheRead),
            cacheWrite: max(0, cacheWrite),
            output: max(0, output),
            reasoningOutput: 0,
            total: max(0, total)
        )
    }

    private func reportedGrokCost(in object: [String: Any]) -> Double? {
        for key in ["costUSD", "cost_usd", "totalCostUSD", "total_cost_usd"] {
            if let value = object.double(key), value >= 0 { return value }
        }
        for key in ["cost_in_usd_ticks", "total_cost_usd_ticks", "costInUSDTicks", "totalCostUSDTicks"] {
            if let ticks = object.double(key), ticks >= 0 { return ticks / 10_000_000_000 }
        }
        return nil
    }

    private func firstUsageDictionary(in value: Any) -> [String: Any]? {
        if let object = value as? [String: Any] {
            if grokUsage(from: object) != nil { return object }
            for key in ["usage", "tokenUsage", "token_usage", "totalUsage", "total_usage"] {
                if let nested = object[key], let found = firstUsageDictionary(in: nested) { return found }
            }
            for nested in object.values {
                if let found = firstUsageDictionary(in: nested) { return found }
            }
        } else if let values = value as? [Any] {
            for nested in values {
                if let found = firstUsageDictionary(in: nested) { return found }
            }
        }
        return nil
    }

    private func firstDictionary(in value: Any, keys: [String]) -> [String: Any]? {
        if let object = value as? [String: Any] {
            for key in keys {
                if let dictionary = object[key] as? [String: Any] { return dictionary }
            }
            for nested in object.values {
                if let found = firstDictionary(in: nested, keys: keys) { return found }
            }
        } else if let values = value as? [Any] {
            for nested in values {
                if let found = firstDictionary(in: nested, keys: keys) { return found }
            }
        }
        return nil
    }

    private func firstString(in value: Any, keys: [String]) -> String? {
        if let object = value as? [String: Any] {
            for key in keys {
                if let string = object[key] as? String, !string.isEmpty { return string }
            }
            for nested in object.values {
                if let found = firstString(in: nested, keys: keys) { return found }
            }
        } else if let values = value as? [Any] {
            for nested in values {
                if let found = firstString(in: nested, keys: keys) { return found }
            }
        }
        return nil
    }

    private func firstDate(in value: Any) -> Date? {
        let keys = ["timestamp", "ts", "createdAt", "created_at", "updatedAt", "updated_at", "startedAt", "started_at"]
        if let object = value as? [String: Any] {
            for key in keys {
                if let string = object[key] as? String {
                    if let date = parseDate(string) { return date }
                    if let raw = Double(string) { return dateFromUnix(raw) }
                }
                if let raw = object.double(key) { return dateFromUnix(raw) }
            }
            for nested in object.values {
                if let found = firstDate(in: nested) { return found }
            }
        } else if let values = value as? [Any] {
            for nested in values {
                if let found = firstDate(in: nested) { return found }
            }
        }
        return nil
    }

    private func dateFromUnix(_ raw: Double) -> Date {
        Date(timeIntervalSince1970: raw > 100_000_000_000 ? raw / 1_000 : raw)
    }

    private func scanZCode(
        databaseURL: URL,
        pricing: PricingCatalog
    ) -> (records: [UsageRecord], scannedFiles: Int, warnings: [String]) {
        guard fileManager.fileExists(atPath: databaseURL.path) else { return ([], 0, []) }

        let query = """
        select id, started_at, provider_id, model_id,
               input_tokens, output_tokens, reasoning_tokens,
               cache_creation_input_tokens, cache_read_input_tokens,
               computed_total_tokens
        from model_usage
        where status = 'completed' and computed_total_tokens > 0;
        """

        let rows = SQLiteReader.rows(at: databaseURL, query: query, columnCount: 10)
        let records = rows.compactMap { values -> UsageRecord? in
            guard values.count == 10,
                  let rawTimestamp = Double(values[1]) else { return nil }

            let model = values[3].isEmpty ? "ZCode Auto" : values[3]
            let inputTotal = max(0, Int(values[4]) ?? 0)
            let output = max(0, Int(values[5]) ?? 0)
            let reasoning = max(0, Int(values[6]) ?? 0)
            let cacheWrite = max(0, Int(values[7]) ?? 0)
            let cacheRead = max(0, Int(values[8]) ?? 0)
            let computedTotal = max(0, Int(values[9]) ?? 0)
            let usage = TokenUsage(
                input: max(0, inputTotal - cacheRead - cacheWrite),
                cachedInput: cacheRead,
                cacheWrite: cacheWrite,
                output: output,
                reasoningOutput: reasoning,
                total: computedTotal > 0 ? computedTotal : inputTotal + output + reasoning
            )
            let timestampSeconds = rawTimestamp > 100_000_000_000 ? rawTimestamp / 1_000 : rawTimestamp
            let quote = pricing.quote(model: model, usage: usage)

            return UsageRecord(
                id: "zcode:\(values[0])",
                timestamp: Date(timeIntervalSince1970: timestampSeconds),
                tool: "ZCode",
                provider: ProviderCatalog.providerName(for: model, fallback: "ZCode"),
                model: model,
                usage: usage,
                costUSD: quote?.amountUSD,
                costBasis: quote?.basis,
                sourcePath: databaseURL.path
            )
        }

        return (records, 1, [])
    }

    private func discoverAgents(records: [UsageRecord], locations: UsageSourceLocations) -> [AgentToolInfo] {
        let requestCountsByTool = Dictionary(grouping: records, by: \.tool).mapValues(\.count)
        let authorizedPaths: [String: [String]] = [
            "claude-code": locations.claudeRoot.map { [$0.path] } ?? [],
            "codex": locations.codexRoot.map { [$0.path] } ?? [],
            "cc-switch": locations.ccSwitchRoot.map { [$0.path] } ?? [],
            "cursor": locations.cursorRoot.map { [$0.path] } ?? [],
            "grok-build": locations.grokRoot.map { [$0.path] } ?? [],
            "zcode": locations.zcodeRoot.map { [$0.path] } ?? []
        ]

        return ProviderCatalog.agentProbes.map { probe in
            var detected = authorizedPaths[probe.id] ?? []
            for rawPath in probe.paths {
                let path = NSString(string: rawPath).expandingTildeInPath
                if fileManager.fileExists(atPath: path), !detected.contains(path) {
                    detected.append(path)
                }
            }
            let requestCount = requestCountsByTool[probe.name] ?? 0
            let hasModelUsage = probe.id == "grok-build" && records.contains {
                $0.model.localizedCaseInsensitiveContains("grok-build")
            }
            let status: ToolSupportStatus
            if requestCount > 0 || hasModelUsage {
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
                detectedPaths: detected,
                note: probe.note
            )
        }
    }

    private struct CodexThreadMeta {
        var provider: String
        var model: String
    }

    private func loadCodexThreadMetadata(databaseURL: URL?) -> [String: CodexThreadMeta] {
        guard let databaseURL,
              fileManager.fileExists(atPath: databaseURL.path) else { return [:] }

        let query = "select id, coalesce(model_provider,''), coalesce(model,'') from threads;"
        var result: [String: CodexThreadMeta] = [:]
        for values in SQLiteReader.rows(at: databaseURL, query: query, columnCount: 3) where values.count == 3 {
            result[values[0]] = CodexThreadMeta(provider: values[1], model: values[2])
        }
        return result
    }

    private func jsonlFiles(under root: URL) -> [URL] {
        guard fileManager.fileExists(atPath: root.path) else { return [] }
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsPackageDescendants, .skipsHiddenFiles]
        ) else {
            return []
        }

        var result: [URL] = []
        for case let file as URL in enumerator where file.pathExtension == "jsonl" {
            result.append(file)
        }
        return result
    }

    private func namedFiles(_ fileNames: [String], under root: URL) -> [URL] {
        guard fileManager.fileExists(atPath: root.path) else { return [] }
        let names = Set(fileNames)
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsPackageDescendants]
        ) else {
            return []
        }

        var result: [URL] = []
        for case let file as URL in enumerator where names.contains(file.lastPathComponent) {
            result.append(file)
        }
        return result
    }

    private func readJSONObject(_ file: URL) -> [String: Any]? {
        guard fileManager.fileExists(atPath: file.path),
              let data = try? Data(contentsOf: file, options: [.mappedIfSafe]),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return object
    }

    private func readJSONLines(
        _ file: URL,
        handle: @escaping ([String: Any]) -> Void,
        onError: @escaping (Error) -> Void
    ) {
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

    func firstInt(_ keys: [String]) -> Int? {
        for key in keys where self[key] != nil {
            if let value = self[key] as? Int { return value }
            if let value = self[key] as? NSNumber { return value.intValue }
            if let value = self[key] as? String, let parsed = Int(value) { return parsed }
        }
        return nil
    }
}
