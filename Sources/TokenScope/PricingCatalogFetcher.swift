import Foundation

/// Downloads the repository price catalog (pricing.json) and caches it locally.
/// The fetch is download-only: no local data leaves the machine, and any failure
/// silently falls back to the compiled built-in table.
final class PricingCatalogFetcher: @unchecked Sendable {
    static let autoUpdateEnabledKey = "pricing.autoUpdateEnabled"
    static let lastFetchedAtKey = "pricing.lastFetchedAt"
    static let etagKey = "pricing.etag"

    let remoteURL: URL
    let cacheURL: URL
    let defaults: UserDefaults

    private let session: URLSession
    private let ttl: TimeInterval = 24 * 60 * 60

    init(
        defaults: UserDefaults = .standard,
        remoteURL: URL = URL(string: "https://raw.githubusercontent.com/ckcsec/TokenScope/main/pricing.json")!,
        cacheDirectory: URL? = nil,
        fileManager: FileManager = .default,
        session: URLSession? = nil
    ) {
        self.defaults = defaults
        self.remoteURL = remoteURL
        let baseDirectory = cacheDirectory
            ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("TokenScope", isDirectory: true)
        self.cacheURL = baseDirectory.appendingPathComponent("pricing-catalog.json")
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 8
            configuration.waitsForConnectivity = false
            self.session = URLSession(configuration: configuration)
        }
    }

    var isAutoUpdateEnabled: Bool {
        defaults.object(forKey: Self.autoUpdateEnabledKey) == nil
            ? true
            : defaults.bool(forKey: Self.autoUpdateEnabledKey)
    }

    func setAutoUpdateEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Self.autoUpdateEnabledKey)
    }

    var lastFetchedAt: Date? {
        defaults.object(forKey: Self.lastFetchedAtKey) as? Date
    }

    func cachedRemotePrices() -> [ModelPrice] {
        guard let data = try? Data(contentsOf: cacheURL) else { return [] }
        return Self.parseCatalog(data)
    }

    func refreshIfNeeded() async -> [ModelPrice] {
        guard isAutoUpdateEnabled else { return [] }
        let cached = cachedRemotePrices()
        if let lastFetchedAt, Date().timeIntervalSince(lastFetchedAt) < ttl, !cached.isEmpty {
            return cached
        }
        return await downloadCatalog(fallback: cached)
    }

    private func downloadCatalog(fallback: [ModelPrice]) async -> [ModelPrice] {
        var request = URLRequest(url: remoteURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        if let etag = defaults.string(forKey: Self.etagKey) {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return fallback }
            if http.statusCode == 304 {
                defaults.set(Date(), forKey: Self.lastFetchedAtKey)
                return fallback
            }
            guard http.statusCode == 200 else { return fallback }

            let prices = Self.parseCatalog(data)
            guard !prices.isEmpty else { return fallback }
            try? FileManager.default.createDirectory(
                at: cacheURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try? data.write(to: cacheURL, options: .atomic)
            defaults.set(Date(), forKey: Self.lastFetchedAtKey)
            if let etag = http.value(forHTTPHeaderField: "ETag") {
                defaults.set(etag, forKey: Self.etagKey)
            }
            return prices
        } catch {
            return fallback
        }
    }

    static func parseCatalog(_ data: Data) -> [ModelPrice] {
        guard let catalog = try? JSONDecoder().decode(RemotePricingCatalog.self, from: data) else {
            return []
        }
        return catalog.models.compactMap { entry in
            let rates = [
                entry.inputPerMillion,
                entry.outputPerMillion,
                entry.cacheReadPerMillion,
                entry.cacheWritePerMillion
            ]
            guard !entry.modelID.isEmpty, rates.allSatisfy({ $0.isFinite && $0 >= 0 }) else {
                return nil
            }
            return ModelPrice(
                modelID: entry.modelID,
                inputPerMillion: entry.inputPerMillion,
                outputPerMillion: entry.outputPerMillion,
                cacheReadPerMillion: entry.cacheReadPerMillion,
                cacheWritePerMillion: entry.cacheWritePerMillion,
                basis: .remote,
                longContextThreshold: entry.longContextThreshold,
                longInputPerMillion: entry.longInputPerMillion,
                longOutputPerMillion: entry.longOutputPerMillion,
                longCacheReadPerMillion: entry.longCacheReadPerMillion
            )
        }
    }
}

private struct RemotePricingCatalog: Codable {
    var version: String
    var models: [RemoteModelPrice]
}

private struct RemoteModelPrice: Codable {
    var modelID: String
    var inputPerMillion: Double
    var outputPerMillion: Double
    var cacheReadPerMillion: Double
    var cacheWritePerMillion: Double
    var longContextThreshold: Int?
    var longInputPerMillion: Double?
    var longOutputPerMillion: Double?
    var longCacheReadPerMillion: Double?
}
