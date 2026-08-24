import Combine
import Foundation

@MainActor
final class UsageStore: ObservableObject {
    @Published var snapshot: UsageSnapshot = .empty
    @Published var isScanning = false

    private let scanner: UsageScanner
    private let cacheURL: URL
    private let refreshInterval: TimeInterval = 5 * 60

    init(scanner: UsageScanner = UsageScanner()) {
        self.scanner = scanner
        let supportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TokenScope", isDirectory: true)
        self.cacheURL = supportDirectory.appendingPathComponent("usage-snapshot.json")

        if let data = try? Data(contentsOf: cacheURL),
           let cached = try? JSONDecoder().decode(UsageSnapshot.self, from: data) {
            snapshot = cached
        }
    }

    func refresh(force: Bool = false) {
        guard !isScanning else { return }
        if !force,
           !snapshot.records.isEmpty,
           Date().timeIntervalSince(snapshot.generatedAt) < refreshInterval {
            return
        }
        isScanning = true

        Task {
            let scanner = self.scanner
            let snapshot = await Task.detached(priority: .userInitiated) {
                scanner.scan()
            }.value
            self.snapshot = snapshot
            self.save(snapshot)
            self.isScanning = false
        }
    }

    private func save(_ snapshot: UsageSnapshot) {
        do {
            try FileManager.default.createDirectory(
                at: cacheURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: cacheURL, options: .atomic)
        } catch {
            // A cache failure should never block live statistics.
        }
    }
}
