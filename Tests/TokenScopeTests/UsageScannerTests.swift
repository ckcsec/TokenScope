import Foundation
import XCTest
@testable import TokenScope

final class UsageScannerTests: XCTestCase {
    func testGrokBuildHeadlessUsageIsParsedWithoutDoubleCountingReasoning() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let session = root
            .appendingPathComponent("sessions/project/session-1", isDirectory: true)
        try FileManager.default.createDirectory(at: session, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let summary = """
        {"model":"grok-build","updatedAt":"2026-08-24T12:00:00Z"}
        """
        let update = """
        {"type":"result","requestId":"request-1","timestamp":"2026-08-24T12:00:00Z","num_turns":7,"usage":{"input_tokens":7210,"cache_read_input_tokens":41000,"cache_creation_input_tokens":0,"output_tokens":1893,"reasoning_tokens":412,"total_tokens":50103},"modelUsage":{"grok-build":{"inputTokens":7210,"outputTokens":1893,"cacheReadInputTokens":41000,"modelCalls":7,"costUSD":0.01268905}},"total_cost_usd":0.01268905}
        """
        try Data(summary.utf8).write(to: session.appendingPathComponent("summary.json"))
        try Data(update.utf8).write(to: session.appendingPathComponent("updates.jsonl"))

        var locations = UsageSourceLocations.empty
        locations.grokRoot = root
        let snapshot = UsageScanner().scan(locations: locations)
        let record = try XCTUnwrap(snapshot.records.first)

        XCTAssertEqual(snapshot.records.count, 1)
        XCTAssertEqual(record.tool, "Grok Build")
        XCTAssertEqual(record.provider, "xAI")
        XCTAssertEqual(record.model, "grok-build")
        XCTAssertEqual(record.usage.input, 7_210)
        XCTAssertEqual(record.usage.cachedInput, 41_000)
        XCTAssertEqual(record.usage.output, 1_893)
        XCTAssertEqual(record.usage.reasoningOutput, 0)
        XCTAssertEqual(record.usage.total, 50_103)
        XCTAssertEqual(record.requestCount, 7)
        XCTAssertEqual(record.costUSD ?? 0, 0.01268905, accuracy: 0.000000001)
        XCTAssertEqual(record.costBasis, .reported)

        let overview = snapshot.overview(period: .all)
        XCTAssertEqual(overview.requestCount, 7)
        XCTAssertEqual(overview.total.total, 50_103)
        XCTAssertEqual(overview.exactCostRequestCount, 7)
    }

    func testCodexModelAttributionFromTurnContextWithoutThreadDatabase() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let session = root
            .appendingPathComponent("sessions/project/session-1", isDirectory: true)
        try FileManager.default.createDirectory(at: session, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let lines = """
        {"type":"session_meta","payload":{"id":"session-1","model_provider":"openai"}}
        {"type":"turn_context","payload":{"turn_id":"turn-1","model":"gpt-5.5"}}
        {"timestamp":"2026-08-27T10:00:00Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":1000,"cached_input_tokens":0,"cache_write_input_tokens":0,"output_tokens":500,"reasoning_output_tokens":0,"total_tokens":1500}}}}
        """
        try Data(lines.utf8).write(to: session.appendingPathComponent("session.jsonl"))

        var locations = UsageSourceLocations.empty
        locations.codexRoot = root
        let snapshot = UsageScanner().scan(locations: locations)
        let record = try XCTUnwrap(snapshot.records.first)

        XCTAssertEqual(snapshot.records.count, 1)
        XCTAssertEqual(record.tool, "Codex")
        XCTAssertEqual(record.model, "gpt-5.5")
        XCTAssertEqual(record.provider, "OpenAI")
        XCTAssertEqual(record.usage.total, 1500)
        XCTAssertEqual(record.costUSD ?? 0, 0.02, accuracy: 0.000000001)
        XCTAssertEqual(record.costBasis, .builtIn)
    }

    func testPricingJSONMatchesBuiltInTable() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let data = try Data(contentsOf: repoRoot.appendingPathComponent("pricing.json"))
        let remote = PricingCatalogFetcher.parseCatalog(data)
        let builtIn = Dictionary(uniqueKeysWithValues: PricingCatalog.builtInPrices.map { ($0.modelID, $0) })

        XCTAssertEqual(Set(remote.map(\.modelID)), Set(builtIn.keys))
        for price in remote {
            let expected = try XCTUnwrap(builtIn[price.modelID])
            XCTAssertEqual(price.basis, .remote)
            XCTAssertEqual(price.inputPerMillion, expected.inputPerMillion)
            XCTAssertEqual(price.outputPerMillion, expected.outputPerMillion)
            XCTAssertEqual(price.cacheReadPerMillion, expected.cacheReadPerMillion)
            XCTAssertEqual(price.cacheWritePerMillion, expected.cacheWritePerMillion)
            XCTAssertEqual(price.longContextThreshold, expected.longContextThreshold)
            XCTAssertEqual(price.longInputPerMillion, expected.longInputPerMillion)
            XCTAssertEqual(price.longOutputPerMillion, expected.longOutputPerMillion)
            XCTAssertEqual(price.longCacheReadPerMillion, expected.longCacheReadPerMillion)
        }
    }

    func testRemotePricesOverrideBuiltIn() throws {
        let catalog = PricingCatalog.load(remotePrices: [
            ModelPrice(
                modelID: "glm-5.3-flash",
                inputPerMillion: 0.12,
                outputPerMillion: 0.4,
                cacheReadPerMillion: 0.02,
                cacheWritePerMillion: 0,
                basis: .remote
            )
        ])
        let usage = TokenUsage(input: 1_000_000, cachedInput: 0, cacheWrite: 0, output: 1_000_000, reasoningOutput: 0, total: 2_000_000)

        let quote = try XCTUnwrap(catalog.quote(model: "glm-5.3-flash", usage: usage))
        XCTAssertEqual(quote.amountUSD, 0.52, accuracy: 0.000000001)
        XCTAssertEqual(quote.basis, .remote)
    }

    func testFetcherDownloadsCachesAndReusesWithinTTL() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let catalogData = try XCTUnwrap(Data("""
        {"version":"test","models":[{"modelID":"glm-5.3-flash","inputPerMillion":0.12,"outputPerMillion":0.4,"cacheReadPerMillion":0.02,"cacheWritePerMillion":0}]}
        """.utf8))
        let suiteName = "TokenScopeTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        MockURLProtocol.requestCount = 0
        MockURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["ETag": "\"test-v1\""]
            )!
            return (response, catalogData)
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        let fetcher = PricingCatalogFetcher(
            defaults: defaults,
            remoteURL: URL(string: "https://example.invalid/pricing.json")!,
            cacheDirectory: root.appendingPathComponent("cache", isDirectory: true),
            session: session
        )

        let prices = await fetcher.refreshIfNeeded()
        XCTAssertEqual(prices.count, 1)
        XCTAssertEqual(prices.first?.modelID, "glm-5.3-flash")
        XCTAssertEqual(prices.first?.basis, .remote)
        XCTAssertNotNil(fetcher.lastFetchedAt)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fetcher.cacheURL.path))
        XCTAssertEqual(MockURLProtocol.requestCount, 1)

        // Second refresh within the TTL serves the cache without hitting the network.
        let cached = await fetcher.refreshIfNeeded()
        XCTAssertEqual(cached.count, 1)
        XCTAssertEqual(MockURLProtocol.requestCount, 1)
    }

    func testFetcherDisabledSkipsNetwork() async {
        let suiteName = "TokenScopeTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(false, forKey: PricingCatalogFetcher.autoUpdateEnabledKey)

        MockURLProtocol.requestCount = 0
        MockURLProtocol.handler = nil
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        let fetcher = PricingCatalogFetcher(
            defaults: defaults,
            remoteURL: URL(string: "https://example.invalid/pricing.json")!,
            session: session
        )
        let prices = await fetcher.refreshIfNeeded()
        XCTAssertTrue(prices.isEmpty)
        XCTAssertEqual(MockURLProtocol.requestCount, 0)
    }
}

private final class MockURLProtocol: URLProtocol {
    static var requestCount = 0
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        MockURLProtocol.requestCount += 1
        guard let handler = MockURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
