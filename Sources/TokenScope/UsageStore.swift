import Combine
import Foundation

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var snapshot: UsageSnapshot = .empty
    @Published var isScanning = false
    @Published private(set) var isShowingDemo = false

    private let scanner: UsageScanner
    private let dataSources: DataSourceAccessManager
    private let pricingFetcher: PricingCatalogFetcher
    private let cacheURL: URL
    private let refreshInterval: TimeInterval = 5 * 60
    private var scanGeneration = 0
    private var baseOverviews: [UsagePeriod: UsageOverview] = [:]
    private var queryOverviews: [OverviewCacheKey: UsageOverview] = [:]
    private var autoRefreshTimer: AnyCancellable?
    private var dayChangedObserver: AnyCancellable?

    @Published var pricingAutoUpdateEnabled: Bool
    @Published private(set) var pricingLastFetchedAt: Date?

    init(
        dataSources: DataSourceAccessManager,
        scanner: UsageScanner = UsageScanner(),
        pricingFetcher: PricingCatalogFetcher = PricingCatalogFetcher()
    ) {
        self.dataSources = dataSources
        self.scanner = scanner
        self.pricingFetcher = pricingFetcher
        self.pricingAutoUpdateEnabled = pricingFetcher.isAutoUpdateEnabled
        self.pricingLastFetchedAt = pricingFetcher.lastFetchedAt
        let supportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TokenScope", isDirectory: true)
        self.cacheURL = supportDirectory.appendingPathComponent("usage-snapshot.json")
    }

    func setPricingAutoUpdateEnabled(_ enabled: Bool) {
        pricingAutoUpdateEnabled = enabled
        pricingFetcher.setAutoUpdateEnabled(enabled)
    }

    /// Keeps statistics current while the app stays open: a periodic rescan
    /// plus a forced rescan the moment the calendar day changes, so "today"
    /// never shows yesterday's numbers after midnight.
    func startAutoRefresh() {
        autoRefreshTimer = Timer.publish(every: refreshInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refresh()
            }
        dayChangedObserver = NotificationCenter.default.publisher(for: .NSCalendarDayChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refresh(force: true)
            }
    }

    func overview(period: UsagePeriod, query: String = "") -> UsageOverview {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalizedQuery.isEmpty, let overview = baseOverviews[period] {
            return overview
        }

        let key = OverviewCacheKey(period: period, query: normalizedQuery)
        if let overview = queryOverviews[key] {
            return overview
        }

        let overview = snapshot.overview(period: period, query: normalizedQuery)
        if queryOverviews.count >= 24 {
            queryOverviews.removeAll(keepingCapacity: true)
        }
        queryOverviews[key] = overview
        return overview
    }

    func refresh(force: Bool = false) {
        guard !isScanning else { return }
        if !force,
           !snapshot.records.isEmpty,
           Date().timeIntervalSince(snapshot.generatedAt) < refreshInterval {
            return
        }
        isScanning = true
        isShowingDemo = false
        scanGeneration += 1
        let generation = scanGeneration
        let locations = dataSources.locations
        let cacheURL = self.cacheURL

        Task {
            if self.snapshot.records.isEmpty,
               locations.hasUsageSource,
               let cached = await Task.detached(priority: .utility, operation: {
                   loadPreparedSnapshot(at: cacheURL)
               }).value {
                guard generation == self.scanGeneration else { return }
                self.apply(cached)
            }

            let scanner = self.scanner
            let pricingFetcher = self.pricingFetcher
            let previousSnapshot = force || self.snapshot.records.isEmpty ? nil : self.snapshot
            let scanPriority: TaskPriority = force ? .userInitiated : .utility
            let prepared = await Task.detached(priority: scanPriority) {
                let remotePrices = await pricingFetcher.refreshIfNeeded()
                return prepareSnapshot(scanner.scan(locations: locations, previousSnapshot: previousSnapshot, remotePrices: remotePrices))
            }.value
            guard generation == self.scanGeneration else { return }
            self.pricingLastFetchedAt = pricingFetcher.lastFetchedAt
            self.apply(prepared)
            self.isScanning = false
            Task.detached(priority: .utility) {
                persist(prepared.snapshot, at: cacheURL)
            }
        }
    }

    func showDemo() {
        scanGeneration += 1
        isScanning = false
        apply(prepareSnapshot(DemoData.snapshot))
        isShowingDemo = true
    }

    func reloadForSourceChange() {
        scanGeneration += 1
        isScanning = false
        isShowingDemo = false
        apply(prepareSnapshot(.empty))
        refresh(force: true)
    }

    private func apply(_ prepared: PreparedUsageSnapshot) {
        baseOverviews = prepared.overviews
        queryOverviews.removeAll(keepingCapacity: true)
        snapshot = prepared.snapshot
    }
}

private struct OverviewCacheKey: Hashable {
    var period: UsagePeriod
    var query: String
}

private struct PreparedUsageSnapshot {
    var snapshot: UsageSnapshot
    var overviews: [UsagePeriod: UsageOverview]
}

private func prepareSnapshot(_ snapshot: UsageSnapshot) -> PreparedUsageSnapshot {
    let overviews = Dictionary(uniqueKeysWithValues: UsagePeriod.allCases.map { period in
        (period, snapshot.overview(period: period))
    })
    return PreparedUsageSnapshot(snapshot: snapshot, overviews: overviews)
}

private func loadPreparedSnapshot(at url: URL) -> PreparedUsageSnapshot? {
    guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]),
          let snapshot = try? JSONDecoder().decode(UsageSnapshot.self, from: data) else {
        return nil
    }
    return prepareSnapshot(snapshot)
}

private func persist(_ snapshot: UsageSnapshot, at url: URL) {
    do {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: url, options: .atomic)
    } catch {
        // Cache failures should never block live statistics.
    }
}
