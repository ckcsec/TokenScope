import Foundation

enum CostBasis: String, Codable, Hashable {
    case reported
    case builtIn
    case remote

    var isEstimated: Bool {
        self != .reported
    }
}

struct CostQuote {
    var amountUSD: Double
    var basis: CostBasis
}

struct ModelPrice {
    var modelID: String
    var inputPerMillion: Double
    var outputPerMillion: Double
    var cacheReadPerMillion: Double
    var cacheWritePerMillion: Double
    var basis: CostBasis
    var longContextThreshold: Int? = nil
    var longInputPerMillion: Double? = nil
    var longOutputPerMillion: Double? = nil
    var longCacheReadPerMillion: Double? = nil
}

struct PricingCatalog {
    private var prices: [String: ModelPrice]

    static func load(remotePrices: [ModelPrice] = []) -> PricingCatalog {
        var prices = Dictionary(uniqueKeysWithValues: builtInPrices.map { ($0.modelID.lowercased(), $0) })
        for price in remotePrices {
            prices[price.modelID.lowercased()] = price
        }
        return PricingCatalog(prices: prices)
    }

    func quote(model: String, usage: TokenUsage) -> CostQuote? {
        guard let price = matchingPrice(for: model) else { return nil }

        let usesLongContext = price.longContextThreshold.map { usage.visibleInput >= $0 } ?? false
        let inputRate = usesLongContext ? (price.longInputPerMillion ?? price.inputPerMillion) : price.inputPerMillion
        let outputRate = usesLongContext ? (price.longOutputPerMillion ?? price.outputPerMillion) : price.outputPerMillion
        let standardCacheReadRate = price.cacheReadPerMillion > 0 ? price.cacheReadPerMillion : price.inputPerMillion
        let cacheReadRate = usesLongContext ? (price.longCacheReadPerMillion ?? standardCacheReadRate) : standardCacheReadRate
        let cacheWriteRate = price.cacheWritePerMillion > 0 ? price.cacheWritePerMillion : inputRate
        let amount = (
            Double(usage.input) * inputRate
                + Double(usage.cachedInput) * cacheReadRate
                + Double(usage.cacheWrite) * cacheWriteRate
                + Double(usage.output + usage.reasoningOutput) * outputRate
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

    static let builtInPrices: [ModelPrice] = [
        // OpenAI standard API pricing.
        ModelPrice(modelID: "gpt-5.6-sol", inputPerMillion: 5, outputPerMillion: 30, cacheReadPerMillion: 0.5, cacheWritePerMillion: 0, basis: .builtIn),
        ModelPrice(modelID: "gpt-5.6", inputPerMillion: 5, outputPerMillion: 30, cacheReadPerMillion: 0.5, cacheWritePerMillion: 0, basis: .builtIn),
        ModelPrice(modelID: "gpt-5.6-terra", inputPerMillion: 2, outputPerMillion: 12, cacheReadPerMillion: 0.2, cacheWritePerMillion: 0, basis: .builtIn),
        ModelPrice(modelID: "gpt-5.6-luna", inputPerMillion: 0.2, outputPerMillion: 1.2, cacheReadPerMillion: 0.02, cacheWritePerMillion: 0, basis: .builtIn),
        ModelPrice(modelID: "gpt-5.5", inputPerMillion: 5, outputPerMillion: 30, cacheReadPerMillion: 0.5, cacheWritePerMillion: 0, basis: .builtIn),
        ModelPrice(modelID: "gpt-5.4", inputPerMillion: 2.5, outputPerMillion: 15, cacheReadPerMillion: 0.25, cacheWritePerMillion: 0, basis: .builtIn),
        ModelPrice(modelID: "gpt-5.3-codex", inputPerMillion: 1.75, outputPerMillion: 14, cacheReadPerMillion: 0.175, cacheWritePerMillion: 0, basis: .builtIn),
        ModelPrice(modelID: "gpt-5.2-codex", inputPerMillion: 1.75, outputPerMillion: 14, cacheReadPerMillion: 0.175, cacheWritePerMillion: 0, basis: .builtIn),

        // Anthropic standard API pricing (5-minute cache writes).
        ModelPrice(modelID: "claude-opus-5", inputPerMillion: 5, outputPerMillion: 25, cacheReadPerMillion: 0.5, cacheWritePerMillion: 6.25, basis: .builtIn),
        ModelPrice(modelID: "claude-fable-5", inputPerMillion: 10, outputPerMillion: 50, cacheReadPerMillion: 1, cacheWritePerMillion: 12.5, basis: .builtIn),
        ModelPrice(modelID: "claude-mythos-5", inputPerMillion: 10, outputPerMillion: 50, cacheReadPerMillion: 1, cacheWritePerMillion: 12.5, basis: .builtIn),
        ModelPrice(modelID: "claude-opus-4-8", inputPerMillion: 5, outputPerMillion: 25, cacheReadPerMillion: 0.5, cacheWritePerMillion: 6.25, basis: .builtIn),
        ModelPrice(modelID: "claude-opus-4-7", inputPerMillion: 5, outputPerMillion: 25, cacheReadPerMillion: 0.5, cacheWritePerMillion: 6.25, basis: .builtIn),
        ModelPrice(modelID: "claude-opus-4-6", inputPerMillion: 5, outputPerMillion: 25, cacheReadPerMillion: 0.5, cacheWritePerMillion: 6.25, basis: .builtIn),
        ModelPrice(modelID: "claude-opus-4-5", inputPerMillion: 5, outputPerMillion: 25, cacheReadPerMillion: 0.5, cacheWritePerMillion: 6.25, basis: .builtIn),
        ModelPrice(modelID: "claude-sonnet-5", inputPerMillion: 3, outputPerMillion: 15, cacheReadPerMillion: 0.3, cacheWritePerMillion: 3.75, basis: .builtIn),
        ModelPrice(modelID: "claude-sonnet-4-6", inputPerMillion: 3, outputPerMillion: 15, cacheReadPerMillion: 0.3, cacheWritePerMillion: 3.75, basis: .builtIn),
        ModelPrice(modelID: "claude-sonnet-4-5", inputPerMillion: 3, outputPerMillion: 15, cacheReadPerMillion: 0.3, cacheWritePerMillion: 3.75, basis: .builtIn),
        ModelPrice(modelID: "claude-haiku-4-5", inputPerMillion: 1, outputPerMillion: 5, cacheReadPerMillion: 0.1, cacheWritePerMillion: 1.25, basis: .builtIn),

        // Google Gemini Developer API standard pricing.
        ModelPrice(modelID: "gemini-3.1-pro-preview", inputPerMillion: 2, outputPerMillion: 12, cacheReadPerMillion: 0.2, cacheWritePerMillion: 0, basis: .builtIn, longContextThreshold: 200_001, longInputPerMillion: 4, longOutputPerMillion: 18, longCacheReadPerMillion: 0.4),
        ModelPrice(modelID: "gemini-3-flash-preview", inputPerMillion: 0.5, outputPerMillion: 3, cacheReadPerMillion: 0.05, cacheWritePerMillion: 0, basis: .builtIn),
        ModelPrice(modelID: "gemini-3.1-flash-lite", inputPerMillion: 0.25, outputPerMillion: 1.5, cacheReadPerMillion: 0.025, cacheWritePerMillion: 0, basis: .builtIn),
        ModelPrice(modelID: "gemini-2.5-pro", inputPerMillion: 1.25, outputPerMillion: 10, cacheReadPerMillion: 0.125, cacheWritePerMillion: 0, basis: .builtIn, longContextThreshold: 200_001, longInputPerMillion: 2.5, longOutputPerMillion: 15, longCacheReadPerMillion: 0.25),
        ModelPrice(modelID: "gemini-2.5-flash", inputPerMillion: 0.3, outputPerMillion: 2.5, cacheReadPerMillion: 0.03, cacheWritePerMillion: 0, basis: .builtIn),
        ModelPrice(modelID: "gemini-2.5-flash-lite", inputPerMillion: 0.1, outputPerMillion: 0.4, cacheReadPerMillion: 0.025, cacheWritePerMillion: 0, basis: .builtIn),

        // xAI short/long context standard API pricing.
        ModelPrice(modelID: "grok-4.6", inputPerMillion: 2, outputPerMillion: 6, cacheReadPerMillion: 0.5, cacheWritePerMillion: 0, basis: .builtIn, longContextThreshold: 200_000, longInputPerMillion: 4, longOutputPerMillion: 12, longCacheReadPerMillion: 1),
        ModelPrice(modelID: "grok-4.5", inputPerMillion: 2, outputPerMillion: 6, cacheReadPerMillion: 0.3, cacheWritePerMillion: 0, basis: .builtIn, longContextThreshold: 200_000, longInputPerMillion: 4, longOutputPerMillion: 12, longCacheReadPerMillion: 0.6),
        ModelPrice(modelID: "grok-4.3", inputPerMillion: 1.25, outputPerMillion: 2.5, cacheReadPerMillion: 0.2, cacheWritePerMillion: 0, basis: .builtIn, longContextThreshold: 200_000, longInputPerMillion: 2.5, longOutputPerMillion: 5, longCacheReadPerMillion: 0.4),
        ModelPrice(modelID: "grok-build", inputPerMillion: 1, outputPerMillion: 2, cacheReadPerMillion: 0.2, cacheWritePerMillion: 0, basis: .builtIn, longContextThreshold: 200_000, longInputPerMillion: 2, longOutputPerMillion: 4, longCacheReadPerMillion: 0.4),
        ModelPrice(modelID: "grok-build-0.1", inputPerMillion: 1, outputPerMillion: 2, cacheReadPerMillion: 0.2, cacheWritePerMillion: 0, basis: .builtIn, longContextThreshold: 200_000, longInputPerMillion: 2, longOutputPerMillion: 4, longCacheReadPerMillion: 0.4),

        // Other commonly encountered international API models.
        ModelPrice(modelID: "command-r-08-2024", inputPerMillion: 0.15, outputPerMillion: 0.6, cacheReadPerMillion: 0, cacheWritePerMillion: 0, basis: .builtIn),
        ModelPrice(modelID: "command-r-plus-08-2024", inputPerMillion: 2.5, outputPerMillion: 10, cacheReadPerMillion: 0, cacheWritePerMillion: 0, basis: .builtIn),

        // Common regional models retained for mixed-provider logs.
        // DeepSeek V4 uses time-of-day pricing (effective 2026-08-17); off-peak rates, peak is 2×.
        ModelPrice(modelID: "deepseek-v4-pro", inputPerMillion: 0.63, outputPerMillion: 1.9, cacheReadPerMillion: 0.021, cacheWritePerMillion: 0, basis: .builtIn),
        ModelPrice(modelID: "deepseek-v4-flash", inputPerMillion: 0.21, outputPerMillion: 0.63, cacheReadPerMillion: 0.007, cacheWritePerMillion: 0, basis: .builtIn),
        ModelPrice(modelID: "glm-5.3", inputPerMillion: 1.4, outputPerMillion: 4.4, cacheReadPerMillion: 0.26, cacheWritePerMillion: 0, basis: .builtIn),
        ModelPrice(modelID: "glm-5.3-flash", inputPerMillion: 0.15, outputPerMillion: 0.5, cacheReadPerMillion: 0.03, cacheWritePerMillion: 0, basis: .builtIn),
        ModelPrice(modelID: "glm-5.2", inputPerMillion: 1.4, outputPerMillion: 4.4, cacheReadPerMillion: 0.26, cacheWritePerMillion: 0, basis: .builtIn),
        ModelPrice(modelID: "kimi-k3", inputPerMillion: 3, outputPerMillion: 15, cacheReadPerMillion: 0.3, cacheWritePerMillion: 3.5, basis: .builtIn),
        ModelPrice(modelID: "kimi-k2.7-code", inputPerMillion: 0.95, outputPerMillion: 4, cacheReadPerMillion: 0.19, cacheWritePerMillion: 0, basis: .builtIn),
        ModelPrice(modelID: "qwen3.8-max", inputPerMillion: 2, outputPerMillion: 6, cacheReadPerMillion: 0.25, cacheWritePerMillion: 2.5, basis: .builtIn)
    ]
}
