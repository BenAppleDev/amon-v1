import SQLite3
import XCTest
@testable import AmonKit

final class SQLiteWorkspaceStoreTests: XCTestCase {
    func testSaveItemEncryptsSensitiveMetadataAtRest() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("amonkit-store-\(UUID().uuidString)", isDirectory: true)
        let databaseURL = directory.appendingPathComponent("workspace.sqlite")

        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let store = try SQLiteWorkspaceStore(
            databaseURL: databaseURL,
            fieldCipher: LocalFieldCipher(fixedKeyData: Data(repeating: 7, count: 32))
        )
        let workspace = try store.createWorkspace(title: "Research Library", description: nil)
        let item = Item(
            workspaceID: workspace.id,
            sourceKind: .retrievedPage,
            resultType: .article,
            title: "Private Title",
            canonicalURL: "https://secret.example.com/page",
            domain: "secret.example.com",
            snippet: "Private snippet",
            pageTitle: "Saved Page",
            cleanedExcerpt: "Readable copy",
            bulletPoints: ["Point one"],
            providerName: "brave",
            providerResultID: "provider-123",
            fetchedAt: Date(),
            contentHash: "hash-123"
        )

        try store.saveItem(item)

        let rawRow = try rawItemRow(at: databaseURL, itemID: item.id)
        XCTAssertNotEqual(rawRow.domain, item.domain)
        XCTAssertNotEqual(rawRow.providerName, item.providerName)
        XCTAssertNotEqual(rawRow.providerResultID, item.providerResultID)
        XCTAssertNotEqual(rawRow.contentHash, item.contentHash)

        let fetched = try XCTUnwrap(try store.fetchItems(workspaceID: workspace.id).first)
        XCTAssertEqual(fetched.domain, item.domain)
        XCTAssertEqual(fetched.providerName, item.providerName)
        XCTAssertEqual(fetched.providerResultID, item.providerResultID)
        XCTAssertEqual(fetched.contentHash, item.contentHash)
    }

    func testSaveCompareArtifactEncryptsFieldKeysAtRest() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("amonkit-store-\(UUID().uuidString)", isDirectory: true)
        let databaseURL = directory.appendingPathComponent("workspace.sqlite")

        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let store = try SQLiteWorkspaceStore(
            databaseURL: databaseURL,
            fieldCipher: LocalFieldCipher(fixedKeyData: Data(repeating: 9, count: 32))
        )
        let workspace = try store.createWorkspace(title: "Research Library", description: nil)
        let rowID = UUID().uuidString
        let artifact = CompareArtifact(
            workspaceID: workspace.id,
            title: "Pricing compare",
            summary: "Compare pricing models",
            itemIDs: ["item-one"],
            rows: [
                CompareRow(
                    id: rowID,
                    compareArtifactID: "artifact-one",
                    fieldKey: "pricing_model",
                    fieldLabel: "Pricing model",
                    rowType: .text,
                    sortOrder: 0,
                    cells: [
                        CompareCell(
                            compareRowID: rowID,
                            itemID: "item-one",
                            valueText: "Tiered"
                        )
                    ]
                )
            ]
        )

        try store.saveCompareArtifact(artifact)

        let rawRow = try rawCompareRow(at: databaseURL, compareArtifactID: artifact.id)
        XCTAssertNotEqual(rawRow.fieldKey, "pricing_model")

        let fetched = try XCTUnwrap(try store.fetchCompareArtifacts(workspaceID: workspace.id).first)
        XCTAssertEqual(fetched.rows.first?.fieldKey, "pricing_model")
    }

    private func rawItemRow(at databaseURL: URL, itemID: String) throws -> (
        domain: String?,
        providerName: String?,
        providerResultID: String?,
        contentHash: String?
    ) {
        var database: OpaquePointer?
        guard sqlite3_open(databaseURL.path, &database) == SQLITE_OK else {
            XCTFail("Could not open raw database for verification")
            throw SQLiteStoreError.openDatabase("raw open failed")
        }
        defer { sqlite3_close(database) }

        let sql = """
        SELECT domain, provider_name, provider_result_id, content_hash
        FROM items
        WHERE id = ?
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            XCTFail("Could not prepare raw verification query")
            throw SQLiteStoreError.prepare("raw prepare failed")
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, itemID, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        guard sqlite3_step(statement) == SQLITE_ROW else {
            XCTFail("Expected stored item row")
            throw SQLiteStoreError.step("raw step failed")
        }

        func text(at column: Int32) -> String? {
            guard let raw = sqlite3_column_text(statement, column) else { return nil }
            return String(cString: raw)
        }

        return (
            domain: text(at: 0),
            providerName: text(at: 1),
            providerResultID: text(at: 2),
            contentHash: text(at: 3)
        )
    }

    private func rawCompareRow(at databaseURL: URL, compareArtifactID: String) throws -> (
        fieldKey: String?
    ) {
        var database: OpaquePointer?
        guard sqlite3_open(databaseURL.path, &database) == SQLITE_OK else {
            XCTFail("Could not open raw database for verification")
            throw SQLiteStoreError.openDatabase("raw open failed")
        }
        defer { sqlite3_close(database) }

        let sql = """
        SELECT field_key
        FROM compare_rows
        WHERE compare_artifact_id = ?
        LIMIT 1
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            XCTFail("Could not prepare raw verification query")
            throw SQLiteStoreError.prepare("raw prepare failed")
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, compareArtifactID, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        guard sqlite3_step(statement) == SQLITE_ROW else {
            XCTFail("Expected stored compare row")
            throw SQLiteStoreError.step("raw step failed")
        }

        func text(at column: Int32) -> String? {
            guard let raw = sqlite3_column_text(statement, column) else { return nil }
            return String(cString: raw)
        }

        return (fieldKey: text(at: 0))
    }
}
