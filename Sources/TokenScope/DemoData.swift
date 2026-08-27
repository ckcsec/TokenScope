import Foundation

enum DemoData {
    static var snapshot: UsageSnapshot {
        let calendar = Calendar.current
        let now = Date()
        let samples: [(Int, Int, String, String, String, TokenUsage, Double?)] = [
            (0, 9, "Codex", "OpenAI", "gpt-5.4", usage(82_400, 31_200, 0, 18_500), 0.49),
            (0, 11, "Claude Code", "Anthropic", "claude-sonnet-4-6", usage(61_000, 112_000, 8_000, 21_300), 0.62),
            (0, 14, "Codex", "OpenAI", "gpt-5.3-codex", usage(94_000, 46_000, 0, 28_600), 0.60),
            (0, 16, "Claude Code", "Anthropic", "claude-opus-4-6", usage(43_000, 67_000, 12_000, 17_800), 0.73),
            (0, 18, "Cursor", "xAI", "grok-4.6", usage(36_000, 0, 0, 0), nil),
            (0, 20, "ZCode", "DeepSeek", "deepseek-v4-pro", usage(48_000, 74_000, 0, 14_600), 0.18),
            (-1, 10, "Codex", "OpenAI", "gpt-5.4", usage(126_000, 55_000, 0, 34_000), 0.91),
            (-1, 15, "Claude Code", "Anthropic", "claude-sonnet-4-6", usage(74_000, 91_000, 6_000, 24_000), 0.69),
            (-1, 18, "ZCode", "Alibaba", "qwen3-coder", usage(53_000, 61_000, 0, 13_200), 0.12),
            (-2, 9, "Codex", "OpenAI", "gpt-5.3-codex", usage(68_000, 38_000, 0, 16_700), 0.39),
            (-2, 13, "Claude Code", "Anthropic", "claude-sonnet-4-6", usage(102_000, 136_000, 11_000, 31_500), 1.04),
            (-3, 11, "Codex", "OpenAI", "gpt-5.4", usage(54_000, 22_000, 0, 12_400), 0.30),
            (-3, 17, "Claude Code", "Anthropic", "claude-opus-4-6", usage(37_000, 48_000, 9_000, 14_200), 0.58),
            (-4, 10, "Claude Code", "Anthropic", "claude-sonnet-4-6", usage(88_000, 121_000, 7_000, 29_000), 0.91),
            (-4, 14, "Codex", "OpenAI", "gpt-5.3-codex", usage(77_000, 33_000, 0, 20_100), 0.46),
            (-5, 9, "Codex", "OpenAI", "gpt-5.4", usage(113_000, 61_000, 0, 27_900), 0.76),
            (-5, 16, "Claude Code", "Anthropic", "claude-opus-4-6", usage(49_000, 82_000, 14_000, 19_600), 0.85),
            (-6, 11, "Claude Code", "Anthropic", "claude-sonnet-4-6", usage(96_000, 144_000, 10_000, 36_000), 1.12),
            (-6, 15, "Codex", "OpenAI", "gpt-5.3-codex", usage(71_000, 42_000, 0, 18_300), 0.43)
        ]

        let records = samples.enumerated().map { index, sample in
            let (dayOffset, hour, tool, provider, model, tokenUsage, cost) = sample
            let day = calendar.date(byAdding: .day, value: dayOffset, to: now) ?? now
            let timestamp = calendar.date(bySettingHour: hour, minute: index % 4 * 12, second: 0, of: day) ?? day
            return UsageRecord(
                id: "demo-\(index)",
                timestamp: timestamp,
                tool: tool,
                provider: provider,
                model: model,
                usage: tokenUsage,
                costUSD: cost,
                costBasis: .builtIn,
                sourcePath: "TokenScope 演示数据"
            )
        }

        let agents = ProviderCatalog.agentProbes.map { probe in
            AgentToolInfo(
                id: probe.id,
                name: probe.name,
                category: probe.category,
                icon: probe.icon,
                status: ["claude-code", "codex", "cursor", "zcode"].contains(probe.id) ? .liveData : .preset,
                canReadTokens: probe.canReadTokens,
                detectedPaths: [],
                note: probe.note
            )
        }

        return UsageSnapshot(
            generatedAt: now,
            records: records.sorted { $0.timestamp > $1.timestamp },
            agents: agents,
            providers: ProviderCatalog.providers,
            scannedFiles: 12,
            warnings: []
        )
    }

    private static func usage(_ input: Int, _ cached: Int, _ cacheWrite: Int, _ output: Int) -> TokenUsage {
        TokenUsage(
            input: input,
            cachedInput: cached,
            cacheWrite: cacheWrite,
            output: output,
            reasoningOutput: 0,
            total: input + cached + cacheWrite + output
        )
    }
}
