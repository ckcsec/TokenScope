import Foundation
import SQLite3

enum SQLiteReader {
    static func rows(at databaseURL: URL, query: String, columnCount: Int) -> [[String]] {
        var database: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX
        guard sqlite3_open_v2(databaseURL.path, &database, flags, nil) == SQLITE_OK,
              let database else {
            if database != nil { sqlite3_close(database) }
            return []
        }
        defer { sqlite3_close(database) }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        var result: [[String]] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let row = (0..<columnCount).map { index -> String in
                guard let text = sqlite3_column_text(statement, Int32(index)) else { return "" }
                return String(cString: text)
            }
            result.append(row)
        }
        return result
    }
}
