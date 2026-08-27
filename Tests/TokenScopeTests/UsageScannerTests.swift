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
}
