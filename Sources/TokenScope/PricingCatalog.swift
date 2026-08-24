import Foundation

enum CostBasis: String, Codable, Hashable {
    case reported
    case ccSwitch
    case builtIn

    var isEstimated: Bool {
        self != .reported
    }
}

struct CostQuote {
    var amountUSD: Double
    var basis: CostBasis
}

private struct ModelPrice {
    var modelID: String
    var inputPerMillion: Double
    var outputPerMillion: Double
    var cacheReadPerMillion: Double
    var cacheWritePerMillion: Double
    var basis: CostBasis
}

struct PricingCatalog {
    private var prices: [String: ModelPrice]

    static func load() -> PricingCatalog {
        var prices = Dictionary(uniqueKeysWithValues: builtInPrices.map { ($0.modelID.lowercased(), $0) })
        for price in loadCCSwitchPrices() {
            prices[price.modelID.lowercased()] = price
        }
        return PricingCatalog(prices: prices)
    }

    func quote(model: String, usage: TokenUsage) -> CostQuote? {
        guard let price = matchingPrice(for: model) else { return nil }

        let cacheReadRate = price.cacheReadPerMillion > 0 ? price.cacheReadPerMillion : price.inputPerMillion
        let cacheWriteRate = price.cacheWritePerMillion > 0 ? price.cacheWritePerMillion : price.inputPerMillion
        let amount = (
            Double(usage.input) * price.inputPerMillion
                + Double(usage.cachedInput) * cacheReadRate
                + Double(usage.cacheWrite) * cacheWriteRate
                + Double(usage.output) * price.outputPerMillion
        ) / 1_000_000

        return CostQuote(amountUSD: amount, basis: price.basis)
    }

    private func matchingPrice(for rawModel: String) -> ModelPrice? {
        let model = rawModel.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.isEmpty, model != "<synthetic>" else { return nil }

        if let exact = prices[model] {
            return exact
        }

        return prices.values
            .sorted { canonicalID($0.modelID).count > canonicalID($1.modelID).count }
            .first { price in
                let key = canonicalID(price.modelID)
                return model == key || model.hasPrefix(key + "-")
            }
    }

    private func canonicalID(_ modelID: String) -> String {
        modelID.lowercased().replacingOccurrences(
            of: "-[0-9]{8}$",
            with: "",
            options: .regularExpression
        )
    }

    private static func loadCCSwitchPrices() -> [ModelPrice] {
        let database = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cc-switch/cc-switch.db")
        guard FileManager.default.fileExists(atPath: database.path) else { return [] }

        let query = """
        select model_id, input_cost_per_million, output_cost_per_million,
               cache_read_cost_per_million, cache_creation_cost_per_million
        from model_pricing;
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = ["-readonly", "-separator", "\t", database.path, query]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        guard process.terminationStatus == 0 else { return [] }
        let output = String(decoding: outputPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)

        return output.split(separator: "\n").compactMap { line in
            let values = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard values.count == 5,
                  let input = Double(values[1]),
                  let output = Double(values[2]),
                  let cacheRead = Double(values[3]),
                  let cacheWrite = Double(values[4]) else {
                return nil
            }
            return ModelPrice(
                modelID: values[0],
                inputPerMillion: input,
                outputPerMillion: output,
                cacheReadPerMillion: cacheRead,
                cacheWritePerMillion: cacheWrite,
                basis: .ccSwitch
            )
        }
    }

    private static let builtInPrices: [ModelPrice] = [
        ModelPrice(modelID: "gpt-5.6-sol", inputPerMillion: 5, outputPerMillion: 30, cacheReadPerMillion: 0.5, cacheWritePerMillion: 6.25, basis: .builtIn),
        ModelPrice(modelID: "gpt-5.6", inputPerMillion: 5, outputPerMillion: 30, cacheReadPerMillion: 0.5, cacheWritePerMillion: 6.25, basis: .builtIn),
        ModelPrice(modelID: "gpt-5.5", inputPerMillion: 5, outputPerMillion: 30, cacheReadPerMillion: 0.5, cacheWritePerMillion: 0, basis: .builtIn),
        ModelPrice(modelID: "gpt-5.4", inputPerMillion: 2.5, outputPerMillion: 15, cacheReadPerMillion: 0.25, cacheWritePerMillion: 0, basis: .builtIn),
        ModelPrice(modelID: "gpt-5.3-codex", inputPerMillion: 1.75, outputPerMillion: 14, cacheReadPerMillion: 0.175, cacheWritePerMillion: 0, basis: .builtIn),
        ModelPrice(modelID: "gpt-5.2-codex", inputPerMillion: 1.75, outputPerMillion: 14, cacheReadPerMillion: 0.175, cacheWritePerMillion: 0, basis: .builtIn),
        ModelPrice(modelID: "claude-opus-5", inputPerMillion: 10, outputPerMillion: 50, cacheReadPerMillion: 1, cacheWritePerMillion: 12.5, basis: .builtIn),
        ModelPrice(modelID: "claude-fable-5", inputPerMillion: 10, outputPerMillion: 50, cacheReadPerMillion: 1, cacheWritePerMillion: 12.5, basis: .builtIn),
        ModelPrice(modelID: "claude-opus-4-8", inputPerMillion: 5, outputPerMillion: 25, cacheReadPerMillion: 0.5, cacheWritePerMillion: 6.25, basis: .builtIn),
        ModelPrice(modelID: "claude-opus-4-6", inputPerMillion: 5, outputPerMillion: 25, cacheReadPerMillion: 0.5, cacheWritePerMillion: 6.25, basis: .builtIn),
        ModelPrice(modelID: "claude-sonnet-5", inputPerMillion: 3, outputPerMillion: 15, cacheReadPerMillion: 0.3, cacheWritePerMillion: 3.75, basis: .builtIn),
        ModelPrice(modelID: "claude-sonnet-4-6", inputPerMillion: 3, outputPerMillion: 15, cacheReadPerMillion: 0.3, cacheWritePerMillion: 3.75, basis: .builtIn),
        ModelPrice(modelID: "deepseek-v4-pro", inputPerMillion: 0.435, outputPerMillion: 0.87, cacheReadPerMillion: 0.003625, cacheWritePerMillion: 0, basis: .builtIn),
        ModelPrice(modelID: "glm-5.2", inputPerMillion: 1.4, outputPerMillion: 4.4, cacheReadPerMillion: 0.26, cacheWritePerMillion: 0, basis: .builtIn),
        ModelPrice(modelID: "kimi-k2.7-code", inputPerMillion: 0.95, outputPerMillion: 4, cacheReadPerMillion: 0.19, cacheWritePerMillion: 0, basis: .builtIn)
    ]
}
