import Foundation

struct AgentProbe {
    var id: String
    var name: String
    var category: String
    var icon: String
    var canReadTokens: Bool
    var note: String
    var paths: [String]
}

enum ProviderCatalog {
    static let providers: [ProviderPreset] = [
        ProviderPreset(id: "custom", name: "自定义配置", category: "Custom", icon: "slider.horizontal.3", accentHex: "0A84FF", featured: true),
        ProviderPreset(id: "openai", name: "OpenAI", category: "Foundation", icon: "sparkles", accentHex: "10A37F", featured: true),
        ProviderPreset(id: "anthropic", name: "Claude Official", category: "Foundation", icon: "a.circle.fill", accentHex: "D97745", featured: true),
        ProviderPreset(id: "codex", name: "Codex", category: "Agent", icon: "command.circle", accentHex: "111827", featured: false),
        ProviderPreset(id: "cursor", name: "Cursor", category: "Agent", icon: "cursorarrow.motionlines", accentHex: "111827", featured: true),
        ProviderPreset(id: "kimi", name: "Kimi", category: "Foundation", icon: "k.circle.fill", accentHex: "5677FF", featured: true),
        ProviderPreset(id: "kimi-coding", name: "Kimi For Coding", category: "Coding", icon: "chevron.left.forwardslash.chevron.right", accentHex: "5B6CFF", featured: true),
        ProviderPreset(id: "deepseek", name: "DeepSeek", category: "Foundation", icon: "water.waves", accentHex: "4F7BFF", featured: false),
        ProviderPreset(id: "gemini", name: "Gemini Native", category: "Foundation", icon: "diamond.fill", accentHex: "4285F4", featured: false),
        ProviderPreset(id: "github-copilot", name: "GitHub Copilot", category: "Coding", icon: "person.crop.circle.badge.checkmark", accentHex: "24292F", featured: false),
        ProviderPreset(id: "openrouter", name: "OpenRouter", category: "Router", icon: "arrow.triangle.branch", accentHex: "6D5DF6", featured: false),
        ProviderPreset(id: "zcode", name: "ZCode", category: "Coding", icon: "z.square.fill", accentHex: "111827", featured: false),
        ProviderPreset(id: "grok-build", name: "Grok Build", category: "Coding", icon: "hammer.circle.fill", accentHex: "111827", featured: false),
        ProviderPreset(id: "siliconflow", name: "SiliconFlow", category: "Router", icon: "square.stack.3d.up.fill", accentHex: "7452E8", featured: true),
        ProviderPreset(id: "siliconflow-en", name: "SiliconFlow en", category: "Router", icon: "square.stack.3d.up.fill", accentHex: "7452E8", featured: true),
        ProviderPreset(id: "zetapi", name: "ZetaAPI", category: "Router", icon: "z.square", accentHex: "6B7280", featured: true),
        ProviderPreset(id: "apinebula", name: "APINebula", category: "Router", icon: "atom", accentHex: "F59E0B", featured: true),
        ProviderPreset(id: "aicodemirror", name: "AICodeMirror", category: "Coding", icon: "wand.and.stars", accentHex: "F97316", featured: true),
        ProviderPreset(id: "pateway", name: "PatewayAI", category: "Router", icon: "circle.grid.cross", accentHex: "111827", featured: true),
        ProviderPreset(id: "fenno", name: "FennoAI", category: "Router", icon: "drop.fill", accentHex: "60A5FA", featured: true),
        ProviderPreset(id: "packycode", name: "PackyCode", category: "Coding", icon: "paperclip", accentHex: "6B7280", featured: true),
        ProviderPreset(id: "runapi", name: "RunAPI", category: "Router", icon: "terminal", accentHex: "18181B", featured: true),
        ProviderPreset(id: "unity2", name: "Unity2.ai", category: "Router", icon: "cube.transparent", accentHex: "111827", featured: true),
        ProviderPreset(id: "subrouter", name: "SubRouter", category: "Router", icon: "point.3.connected.trianglepath.dotted", accentHex: "14B8A6", featured: true),
        ProviderPreset(id: "apikeyfun", name: "APIKEY.FUN", category: "Router", icon: "key.fill", accentHex: "F97316", featured: true),
        ProviderPreset(id: "claudeapi", name: "ClaudeAPI", category: "Router", icon: "asterisk", accentHex: "D97745", featured: true),
        ProviderPreset(id: "code0", name: "Code0", category: "Coding", icon: "equal.circle", accentHex: "22C55E", featured: true),
        ProviderPreset(id: "teamorouter", name: "TeamoRouter", category: "Router", icon: "point.3.filled.connected.trianglepath.dotted", accentHex: "1F2937", featured: true),
        ProviderPreset(id: "claudecn", name: "ClaudeCN", category: "Router", icon: "seal.fill", accentHex: "EA580C", featured: true),
        ProviderPreset(id: "byteplus", name: "BytePlus", category: "Cloud", icon: "bolt.fill", accentHex: "2563EB", featured: false),
        ProviderPreset(id: "doubao", name: "DouBaoSeed", category: "Foundation", icon: "circle.hexagongrid.fill", accentHex: "7C3AED", featured: false),
        ProviderPreset(id: "volcengine", name: "火山引擎", category: "Cloud", icon: "mountain.2.fill", accentHex: "0284C7", featured: true),
        ProviderPreset(id: "shengsuan", name: "胜算云", category: "Cloud", icon: "server.rack", accentHex: "6366F1", featured: true),
        ProviderPreset(id: "aigocode", name: "AIGoCode", category: "Coding", icon: "curlybraces", accentHex: "3B82F6", featured: true),
        ProviderPreset(id: "nekocode", name: "NekoCode", category: "Coding", icon: "hexagon.fill", accentHex: "E879F9", featured: false),
        ProviderPreset(id: "atlascloud", name: "AtlasCloud", category: "Cloud", icon: "location.north.fill", accentHex: "111827", featured: false),
        ProviderPreset(id: "aws-bedrock", name: "AWS Bedrock", category: "Cloud", icon: "cloud.fill", accentHex: "FF9900", featured: false),
        ProviderPreset(id: "baidu-qianfan", name: "Baidu Qianfan", category: "Cloud", icon: "pawprint.fill", accentHex: "4F46E5", featured: false),
        ProviderPreset(id: "bailian", name: "Bailian", category: "Cloud", icon: "cube.fill", accentHex: "7C3AED", featured: false),
        ProviderPreset(id: "alibaba-qwen", name: "Qwen", category: "Foundation", icon: "q.circle.fill", accentHex: "2563EB", featured: false),
        ProviderPreset(id: "modelscope", name: "ModelScope", category: "Model Hub", icon: "scope", accentHex: "6366F1", featured: false),
        ProviderPreset(id: "minimax", name: "MiniMax", category: "Foundation", icon: "waveform", accentHex: "FF477E", featured: false),
        ProviderPreset(id: "stepfun", name: "StepFun", category: "Foundation", icon: "stairs", accentHex: "2563EB", featured: false),
        ProviderPreset(id: "zhipu", name: "Zhipu GLM", category: "Foundation", icon: "circle.grid.3x3.fill", accentHex: "3B82F6", featured: false),
        ProviderPreset(id: "xai", name: "xAI (Grok)", category: "Foundation", icon: "xmark", accentHex: "111827", featured: false),
        ProviderPreset(id: "mistral", name: "Mistral", category: "Foundation", icon: "wind", accentHex: "F97316", featured: false),
        ProviderPreset(id: "cohere", name: "Cohere", category: "Foundation", icon: "c.circle.fill", accentHex: "06B6D4", featured: false),
        ProviderPreset(id: "perplexity", name: "Perplexity", category: "Search", icon: "magnifyingglass.circle.fill", accentHex: "0EA5E9", featured: false),
        ProviderPreset(id: "groq", name: "Groq", category: "Inference", icon: "speedometer", accentHex: "EF4444", featured: false),
        ProviderPreset(id: "together", name: "Together AI", category: "Inference", icon: "person.2.wave.2.fill", accentHex: "0F766E", featured: false),
        ProviderPreset(id: "fireworks", name: "Fireworks AI", category: "Inference", icon: "sparkle", accentHex: "DC2626", featured: false),
        ProviderPreset(id: "azure-openai", name: "Azure OpenAI", category: "Cloud", icon: "cloud.bolt.fill", accentHex: "0078D4", featured: false),
        ProviderPreset(id: "vertex", name: "Vertex AI", category: "Cloud", icon: "v.circle.fill", accentHex: "34A853", featured: false),
        ProviderPreset(id: "meta", name: "Meta Llama", category: "Foundation", icon: "infinity", accentHex: "0668E1", featured: false),
        ProviderPreset(id: "ai21", name: "AI21 Labs", category: "Foundation", icon: "a.square.fill", accentHex: "111827", featured: false),
        ProviderPreset(id: "cerebras", name: "Cerebras", category: "Inference", icon: "cpu.fill", accentHex: "F97316", featured: false),
        ProviderPreset(id: "sambanova", name: "SambaNova", category: "Inference", icon: "wave.3.right.circle.fill", accentHex: "DC2626", featured: false),
        ProviderPreset(id: "nvidia", name: "Nvidia", category: "Inference", icon: "eye.fill", accentHex: "76B900", featured: false),
        ProviderPreset(id: "novita", name: "Novita AI", category: "Inference", icon: "triangle.fill", accentHex: "111827", featured: false),
        ProviderPreset(id: "huggingface", name: "Hugging Face", category: "Model Hub", icon: "face.smiling", accentHex: "FBBF24", featured: false),
        ProviderPreset(id: "replicate", name: "Replicate", category: "Model Hub", icon: "square.3.layers.3d", accentHex: "111827", featured: false),
        ProviderPreset(id: "rightcode", name: "RightCode", category: "Coding", icon: "r.circle.fill", accentHex: "F97316", featured: true),
        ProviderPreset(id: "etok", name: "ETok.ai", category: "Router", icon: "e.circle", accentHex: "F97316", featured: true),
        ProviderPreset(id: "cubence", name: "Cubence", category: "Router", icon: "shippingbox.fill", accentHex: "374151", featured: true),
        ProviderPreset(id: "dmxapi", name: "DMXAPI", category: "Router", icon: "d.circle", accentHex: "6B7280", featured: false),
        ProviderPreset(id: "sudocode-chat", name: "SudoCode.chat", category: "Coding", icon: "terminal.fill", accentHex: "7C3AED", featured: true),
        ProviderPreset(id: "sudocode-us", name: "SudoCode.us", category: "Coding", icon: "terminal.fill", accentHex: "A855F7", featured: true),
        ProviderPreset(id: "aihubmix", name: "AiHubMix", category: "Router", icon: "flame.fill", accentHex: "0EA5E9", featured: false),
        ProviderPreset(id: "amux", name: "Amux", category: "Router", icon: "a.circle", accentHex: "111827", featured: false),
        ProviderPreset(id: "cherryin", name: "CherryIN", category: "Router", icon: "inset.filled.circle", accentHex: "FF5A5F", featured: false),
        ProviderPreset(id: "longcat", name: "Longcat", category: "Foundation", icon: "m.circle.fill", accentHex: "22C55E", featured: false)
    ]

    static let agentProbes: [AgentProbe] = [
        AgentProbe(id: "claude-code", name: "Claude Code", category: "CLI Agent", icon: "a.circle.fill", canReadTokens: true, note: "读取 ~/.claude/projects JSONL", paths: ["~/.claude/projects"]),
        AgentProbe(id: "codex", name: "Codex", category: "Desktop/CLI Agent", icon: "command.circle", canReadTokens: true, note: "读取 ~/.codex/sessions JSONL", paths: ["~/.codex/sessions", "~/Library/Application Support/Codex"]),
        AgentProbe(id: "cc-switch", name: "CC Switch", category: "Provider Manager", icon: "arrow.left.arrow.right.circle", canReadTokens: false, note: "作为供应商/代理配置入口识别", paths: ["~/Library/Application Support/cc-switch", "~/.cc-switch"]),
        AgentProbe(id: "cursor", name: "Cursor", category: "IDE Agent", icon: "cursorarrow.motionlines", canReadTokens: true, note: "读取 Cursor state.vscdb 的请求、模型和上下文 Token", paths: ["~/Library/Application Support/Cursor"]),
        AgentProbe(id: "zcode", name: "ZCode", category: "IDE Agent", icon: "z.square.fill", canReadTokens: true, note: "读取 ~/.zcode/cli/db/db.sqlite 的精确模型用量", paths: ["~/Library/Application Support/ZCode", "~/.zcode"]),
        AgentProbe(id: "grok-cli", name: "Grok CLI", category: "CLI Agent", icon: "xmark.circle.fill", canReadTokens: false, note: "检测 ~/.grok；精确 token 可通过 Grok External OTEL 接入", paths: ["~/.grok", "~/.local/bin/grok"]),
        AgentProbe(id: "grok-bot", name: "Grok Bot", category: "Desktop Agent", icon: "message.badge.circle.fill", canReadTokens: false, note: "检测 Grok Bot 应用目录", paths: ["~/Library/Application Support/Grok Bot", "~/.grokbot"]),
        AgentProbe(id: "grok-build", name: "Grok Build", category: "Coding Agent", icon: "hammer.circle.fill", canReadTokens: true, note: "读取 ~/.grok 会话中的逐请求 Token 和本地汇总信号", paths: ["~/Library/Application Support/Grok Build", "~/Library/Application Support/Grok Code", "~/.grok/build", "~/.grok"]),
        AgentProbe(id: "cline", name: "Cline", category: "VS Code Agent", icon: "chevron.left.forwardslash.chevron.right", canReadTokens: false, note: "检测 VS Code 扩展数据目录", paths: ["~/Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev", "~/Library/Application Support/Cursor/User/globalStorage/saoudrizwan.claude-dev"]),
        AgentProbe(id: "roo-code", name: "Roo Code", category: "VS Code Agent", icon: "square.stack.3d.up", canReadTokens: false, note: "检测 Roo/Cline 系数据目录", paths: ["~/Library/Application Support/Code/User/globalStorage/rooveterinaryinc.roo-cline", "~/Library/Application Support/Cursor/User/globalStorage/rooveterinaryinc.roo-cline"]),
        AgentProbe(id: "continue", name: "Continue", category: "IDE Agent", icon: "play.circle", canReadTokens: false, note: "检测 ~/.continue", paths: ["~/.continue", "~/Library/Application Support/Code/User/globalStorage/continue.continue"]),
        AgentProbe(id: "aider", name: "Aider", category: "CLI Agent", icon: "terminal", canReadTokens: false, note: "检测 Aider 配置和历史文件", paths: ["~/.aider.conf.yml", "~/.aider.chat.history.md"]),
        AgentProbe(id: "opencode", name: "OpenCode", category: "CLI Agent", icon: "square.split.2x2", canReadTokens: false, note: "检测 OpenCode 配置目录", paths: ["~/.config/opencode", "~/.local/share/opencode"]),
        AgentProbe(id: "gemini-cli", name: "Gemini CLI", category: "CLI Agent", icon: "diamond.fill", canReadTokens: false, note: "检测 ~/.gemini", paths: ["~/.gemini"]),
        AgentProbe(id: "github-copilot", name: "GitHub Copilot", category: "IDE Agent", icon: "person.crop.circle.badge.checkmark", canReadTokens: false, note: "检测 Copilot 本机配置", paths: ["~/.config/github-copilot", "~/Library/Application Support/Code/User/globalStorage/github.copilot", "~/Library/Application Support/Cursor/User/globalStorage/github.copilot"]),
        AgentProbe(id: "windsurf", name: "Windsurf", category: "IDE Agent", icon: "wind", canReadTokens: false, note: "检测 Windsurf 应用目录", paths: ["~/Library/Application Support/Windsurf"]),
        AgentProbe(id: "trae", name: "Trae", category: "IDE Agent", icon: "bolt.horizontal.circle", canReadTokens: false, note: "检测 Trae 应用目录", paths: ["~/Library/Application Support/Trae CN", "~/Library/Application Support/Trae"]),
        AgentProbe(id: "zed", name: "Zed AI", category: "IDE Agent", icon: "z.square", canReadTokens: false, note: "检测 Zed 配置目录", paths: ["~/.config/zed", "~/Library/Application Support/Zed"]),
        AgentProbe(id: "chatgpt-desktop", name: "ChatGPT Desktop", category: "Desktop Agent", icon: "message.circle", canReadTokens: false, note: "检测 OpenAI/ChatGPT 应用目录", paths: ["~/Library/Application Support/OpenAI", "~/Library/Application Support/ChatGPT"]),
        AgentProbe(id: "codebuddy", name: "CodeBuddy", category: "IDE Agent", icon: "curlybraces.square", canReadTokens: false, note: "检测 CodeBuddy 应用目录", paths: ["~/Library/Application Support/CodeBuddyExtension"])
    ]

    static func providerName(for model: String, fallback: String = "Unknown") -> String {
        let lower = model.lowercased()
        if lower.contains("claude") { return "Anthropic" }
        if lower.contains("gpt") || lower.contains("codex") || lower.contains("o1") || lower.contains("o3") || lower.contains("o4") { return "OpenAI" }
        if lower.contains("deepseek") { return "DeepSeek" }
        if lower.contains("gemini") { return "Google" }
        if lower.contains("kimi") || lower.contains("moonshot") { return "Kimi" }
        if lower.contains("qwen") || lower.contains("qwq") || lower.contains("bailian") { return "Alibaba" }
        if lower.contains("doubao") || lower.contains("seed") { return "ByteDance" }
        if lower.contains("glm") || lower.contains("zhipu") { return "Zhipu GLM" }
        if lower.contains("grok") || lower.contains("xai") { return "xAI" }
        if lower.contains("mistral") || lower.contains("mixtral") { return "Mistral" }
        if lower.contains("llama") { return "Meta" }
        if lower.contains("command-r") || lower.contains("command-a") { return "Cohere" }
        if lower.contains("sonar") { return "Perplexity" }
        if lower.contains("nova") { return "Amazon" }
        if lower.contains("jamba") { return "AI21 Labs" }
        if lower.contains("cerebras") { return "Cerebras" }
        if lower.contains("composer") || lower.contains("cursor") { return "Cursor" }
        return fallback
    }
}
