import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public enum SQLiteStoreError: Error, LocalizedError {
    case openDatabase(String)
    case prepare(String)
    case step(String)
    case bind(String)
    case missingWorkspace(String)

    public var errorDescription: String? {
        switch self {
        case .openDatabase(let message):
            return "Could not open database: \(message)"
        case .prepare(let message):
            return "Could not prepare statement: \(message)"
        case .step(let message):
            return "Database execution failed: \(message)"
        case .bind(let message):
            return "Failed to bind value: \(message)"
        case .missingWorkspace(let id):
            return "Workspace not found: \(id)"
        }
    }
}

private enum SQLiteValue {
    case text(String?)
    case int(Int)
}

public final class SQLiteWorkspaceStore: WorkspaceStore {
    private var db: OpaquePointer?
    private let fieldCipher: LocalFieldCipher

    public init(databaseURL: URL, fieldCipher: LocalFieldCipher = LocalFieldCipher()) throws {
        self.fieldCipher = fieldCipher
        try FileManager.default.createDirectory(at: databaseURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
        var database: OpaquePointer?
        if sqlite3_open(databaseURL.path, &database) != SQLITE_OK {
            throw SQLiteStoreError.openDatabase(String(cString: sqlite3_errmsg(database)))
        }
        self.db = database
        try applyFileProtection(to: databaseURL)
        for statement in LocalSchema.createStatements {
            try execute(statement)
        }
    }

    deinit {
        sqlite3_close(db)
    }

    public func createWorkspace(title: String, description: String?) throws -> Workspace {
        let workspace = Workspace(title: title, description: description)
        try saveWorkspace(workspace)
        return workspace
    }

    public func saveWorkspace(_ workspace: Workspace) throws {
        let sql = """
        INSERT OR REPLACE INTO workspaces (
            id, title, description, color_tag, icon_name, created_at, updated_at, last_opened_at, is_archived, export_version, local_schema_version
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        try execute(sql, bindings: [
            .text(workspace.id),
            .text(try fieldCipher.encrypt(workspace.title)),
            .text(try fieldCipher.encrypt(workspace.description)),
            .text(workspace.colorTag),
            .text(workspace.iconName),
            .text(AmonCoders.storageDateFormatter.string(from: workspace.createdAt)),
            .text(AmonCoders.storageDateFormatter.string(from: workspace.updatedAt)),
            .text(workspace.lastOpenedAt.map { AmonCoders.storageDateFormatter.string(from: $0) }),
            .int(workspace.isArchived ? 1 : 0),
            .int(workspace.exportVersion),
            .int(workspace.localSchemaVersion),
        ])
    }

    public func fetchWorkspaces() throws -> [Workspace] {
        try query(
            "SELECT id, title, description, color_tag, icon_name, created_at, updated_at, last_opened_at, is_archived, export_version, local_schema_version FROM workspaces ORDER BY updated_at DESC"
        ) { stmt in
            Workspace(
                id: Self.text(stmt, column: 0) ?? UUID().uuidString,
                title: try self.fieldCipher.decrypt(Self.text(stmt, column: 1)) ?? "Untitled",
                description: try self.fieldCipher.decrypt(Self.text(stmt, column: 2)),
                colorTag: Self.text(stmt, column: 3),
                iconName: Self.text(stmt, column: 4),
                createdAt: Self.date(stmt, column: 5) ?? Date(),
                updatedAt: Self.date(stmt, column: 6) ?? Date(),
                lastOpenedAt: Self.date(stmt, column: 7),
                isArchived: Self.int(stmt, column: 8) == 1,
                exportVersion: Self.int(stmt, column: 9),
                localSchemaVersion: Self.int(stmt, column: 10)
            )
        }
    }

    public func fetchWorkspace(id: String) throws -> Workspace? {
        try fetchWorkspaces().first(where: { $0.id == id })
    }

    public func saveItem(_ item: Item) throws {
        let sql = """
        INSERT OR REPLACE INTO items (
            id, workspace_id, source_kind, result_type, title, canonical_url, domain, snippet, page_title, cleaned_excerpt,
            bullet_points_json, provider_name, provider_result_id, fetched_at, saved_at, updated_at,
            typed_metadata_json, source_metadata_json, content_hash, is_deleted
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        try execute(sql, bindings: [
            .text(item.id), .text(item.workspaceID), .text(item.sourceKind.rawValue), .text(item.resultType.rawValue),
            .text(try fieldCipher.encrypt(item.title)), .text(try fieldCipher.encrypt(item.canonicalURL)), .text(item.domain),
            .text(try fieldCipher.encrypt(item.snippet)), .text(try fieldCipher.encrypt(item.pageTitle)), .text(try fieldCipher.encrypt(item.cleanedExcerpt)),
            .text(try encode(item.bulletPoints)), .text(item.providerName), .text(item.providerResultID),
            .text(item.fetchedAt.map { AmonCoders.storageDateFormatter.string(from: $0) }),
            .text(AmonCoders.storageDateFormatter.string(from: item.savedAt)),
            .text(AmonCoders.storageDateFormatter.string(from: item.updatedAt)),
            .text(try encode(item.typedMetadata)), .text(try encode(item.sourceMetadata)), .text(item.contentHash), .int(item.isDeleted ? 1 : 0)
        ])
    }

    public func fetchItems(workspaceID: String) throws -> [Item] {
        try query(
            "SELECT id, workspace_id, source_kind, result_type, title, canonical_url, domain, snippet, page_title, cleaned_excerpt, bullet_points_json, provider_name, provider_result_id, fetched_at, saved_at, updated_at, typed_metadata_json, source_metadata_json, content_hash, is_deleted FROM items WHERE workspace_id = ? ORDER BY saved_at DESC",
            bindings: [.text(workspaceID)]
        ) { stmt in
            Item(
                id: Self.text(stmt, column: 0) ?? UUID().uuidString,
                workspaceID: Self.text(stmt, column: 1) ?? workspaceID,
                sourceKind: SourceKind(rawValue: Self.text(stmt, column: 2) ?? SourceKind.searchResult.rawValue) ?? .searchResult,
                resultType: ResultType(rawValue: Self.text(stmt, column: 3) ?? ResultType.webPage.rawValue) ?? .webPage,
                title: try self.fieldCipher.decrypt(Self.text(stmt, column: 4)) ?? "Untitled",
                canonicalURL: try self.fieldCipher.decrypt(Self.text(stmt, column: 5)) ?? "",
                domain: Self.text(stmt, column: 6) ?? "",
                snippet: try self.fieldCipher.decrypt(Self.text(stmt, column: 7)),
                pageTitle: try self.fieldCipher.decrypt(Self.text(stmt, column: 8)),
                cleanedExcerpt: try self.fieldCipher.decrypt(Self.text(stmt, column: 9)),
                bulletPoints: try self.decodeArray(Self.text(stmt, column: 10)) ?? [],
                providerName: Self.text(stmt, column: 11),
                providerResultID: Self.text(stmt, column: 12),
                fetchedAt: Self.date(stmt, column: 13),
                savedAt: Self.date(stmt, column: 14) ?? Date(),
                updatedAt: Self.date(stmt, column: 15) ?? Date(),
                typedMetadata: try self.decodeObject(Self.text(stmt, column: 16)) ?? [:],
                sourceMetadata: try self.decodeObject(Self.text(stmt, column: 17)) ?? [:],
                contentHash: Self.text(stmt, column: 18),
                isDeleted: Self.int(stmt, column: 19) == 1
            )
        }
    }

    public func saveNote(_ note: Note) throws {
        let sql = "INSERT OR REPLACE INTO notes (id, workspace_id, item_id, compare_artifact_id, scope_type, body, created_at, updated_at, is_deleted) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)"
        try execute(sql, bindings: [
            .text(note.id), .text(note.workspaceID), .text(note.itemID), .text(note.compareArtifactID), .text(note.scopeType.rawValue),
            .text(try fieldCipher.encrypt(note.body)), .text(AmonCoders.storageDateFormatter.string(from: note.createdAt)),
            .text(AmonCoders.storageDateFormatter.string(from: note.updatedAt)), .int(note.isDeleted ? 1 : 0)
        ])
    }

    public func fetchNotes(workspaceID: String) throws -> [Note] {
        try query(
            "SELECT id, workspace_id, item_id, compare_artifact_id, scope_type, body, created_at, updated_at, is_deleted FROM notes WHERE workspace_id = ? OR item_id IN (SELECT id FROM items WHERE workspace_id = ?) OR compare_artifact_id IN (SELECT id FROM compare_artifacts WHERE workspace_id = ?) ORDER BY updated_at DESC",
            bindings: [.text(workspaceID), .text(workspaceID), .text(workspaceID)]
        ) { stmt in
            Note(
                id: Self.text(stmt, column: 0) ?? UUID().uuidString,
                workspaceID: Self.text(stmt, column: 1),
                itemID: Self.text(stmt, column: 2),
                compareArtifactID: Self.text(stmt, column: 3),
                scopeType: NoteScopeType(rawValue: Self.text(stmt, column: 4) ?? NoteScopeType.workspace.rawValue) ?? .workspace,
                body: try self.fieldCipher.decrypt(Self.text(stmt, column: 5)) ?? "",
                createdAt: Self.date(stmt, column: 6) ?? Date(),
                updatedAt: Self.date(stmt, column: 7) ?? Date(),
                isDeleted: Self.int(stmt, column: 8) == 1
            )
        }
    }

    public func saveCompareArtifact(_ artifact: CompareArtifact) throws {
        let baseSQL = "INSERT OR REPLACE INTO compare_artifacts (id, workspace_id, title, summary, compare_schema_version, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)"
        try execute(baseSQL, bindings: [
            .text(artifact.id), .text(artifact.workspaceID), .text(try fieldCipher.encrypt(artifact.title)),
            .text(try fieldCipher.encrypt(artifact.summary)), .int(artifact.compareSchemaVersion),
            .text(AmonCoders.storageDateFormatter.string(from: artifact.createdAt)),
            .text(AmonCoders.storageDateFormatter.string(from: artifact.updatedAt))
        ])
        try execute("DELETE FROM compare_artifact_items WHERE compare_artifact_id = ?", bindings: [.text(artifact.id)])
        try execute("DELETE FROM compare_cells WHERE compare_row_id IN (SELECT id FROM compare_rows WHERE compare_artifact_id = ?)", bindings: [.text(artifact.id)])
        try execute("DELETE FROM compare_rows WHERE compare_artifact_id = ?", bindings: [.text(artifact.id)])

        for (index, itemID) in artifact.itemIDs.enumerated() {
            try execute(
                "INSERT INTO compare_artifact_items (id, compare_artifact_id, item_id, sort_order) VALUES (?, ?, ?, ?)",
                bindings: [.text(UUID().uuidString), .text(artifact.id), .text(itemID), .int(index)]
            )
        }

        for row in artifact.rows {
            try execute(
                "INSERT OR REPLACE INTO compare_rows (id, compare_artifact_id, field_key, field_label, row_type, sort_order) VALUES (?, ?, ?, ?, ?, ?)",
                bindings: [.text(row.id), .text(artifact.id), .text(row.fieldKey), .text(try fieldCipher.encrypt(row.fieldLabel)), .text(row.rowType.rawValue), .int(row.sortOrder)]
            )
            for cell in row.cells {
                try execute(
                    "INSERT OR REPLACE INTO compare_cells (id, compare_row_id, item_id, value_text, value_json, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
                    bindings: [
                        .text(cell.id), .text(row.id), .text(cell.itemID), .text(try fieldCipher.encrypt(cell.valueText)),
                        .text(try encode(cell.valueJSON)), .text(AmonCoders.storageDateFormatter.string(from: cell.createdAt)),
                        .text(AmonCoders.storageDateFormatter.string(from: cell.updatedAt))
                    ]
                )
            }
        }
    }

    public func fetchCompareArtifacts(workspaceID: String) throws -> [CompareArtifact] {
        let baseRows: [(String, String, String?, Int, Date, Date)] = try query(
            "SELECT id, title, summary, compare_schema_version, created_at, updated_at FROM compare_artifacts WHERE workspace_id = ? ORDER BY updated_at DESC",
            bindings: [.text(workspaceID)]
        ) { stmt in
            (
                Self.text(stmt, column: 0) ?? UUID().uuidString,
                try self.fieldCipher.decrypt(Self.text(stmt, column: 1)) ?? "Untitled Compare",
                try self.fieldCipher.decrypt(Self.text(stmt, column: 2)),
                Self.int(stmt, column: 3),
                Self.date(stmt, column: 4) ?? Date(),
                Self.date(stmt, column: 5) ?? Date()
            )
        }
        return try baseRows.map { row in
            let itemIDs: [String] = try query(
                "SELECT item_id FROM compare_artifact_items WHERE compare_artifact_id = ? ORDER BY sort_order ASC",
                bindings: [.text(row.0)]
            ) { stmt in Self.text(stmt, column: 0) ?? "" }
            let compareRows = try fetchCompareRows(compareArtifactID: row.0)
            return CompareArtifact(
                id: row.0,
                workspaceID: workspaceID,
                title: row.1,
                summary: row.2,
                compareSchemaVersion: row.3,
                createdAt: row.4,
                updatedAt: row.5,
                itemIDs: itemIDs,
                rows: compareRows
            )
        }
    }

    public func saveResearchArtifact(_ artifact: ResearchArtifact) throws {
        let sql = "INSERT OR REPLACE INTO research_artifacts (id, workspace_id, title, prompt_context, summary_text, bullet_summary_json, model_name, model_version, generation_mode, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
        try execute(sql, bindings: [
            .text(artifact.id), .text(artifact.workspaceID), .text(try fieldCipher.encrypt(artifact.title)),
            .text(try fieldCipher.encrypt(artifact.promptContext)), .text(try fieldCipher.encrypt(artifact.summaryText)),
            .text(try encode(artifact.bulletSummary)), .text(artifact.modelName), .text(artifact.modelVersion), .text(artifact.generationMode.rawValue),
            .text(AmonCoders.storageDateFormatter.string(from: artifact.createdAt)), .text(AmonCoders.storageDateFormatter.string(from: artifact.updatedAt))
        ])
        try execute("DELETE FROM research_artifact_items WHERE research_artifact_id = ?", bindings: [.text(artifact.id)])
        for (index, itemID) in artifact.itemIDs.enumerated() {
            try execute(
                "INSERT INTO research_artifact_items (id, research_artifact_id, item_id, sort_order) VALUES (?, ?, ?, ?)",
                bindings: [.text(UUID().uuidString), .text(artifact.id), .text(itemID), .int(index)]
            )
        }
    }

    public func fetchResearchArtifacts(workspaceID: String) throws -> [ResearchArtifact] {
        let baseRows: [(String, String, String?, String, [String], String?, String?, GenerationMode, Date, Date)] = try query(
            "SELECT id, title, prompt_context, summary_text, bullet_summary_json, model_name, model_version, generation_mode, created_at, updated_at FROM research_artifacts WHERE workspace_id = ? ORDER BY updated_at DESC",
            bindings: [.text(workspaceID)]
        ) { stmt in
            (
                Self.text(stmt, column: 0) ?? UUID().uuidString,
                try self.fieldCipher.decrypt(Self.text(stmt, column: 1)) ?? "Untitled Research",
                try self.fieldCipher.decrypt(Self.text(stmt, column: 2)),
                try self.fieldCipher.decrypt(Self.text(stmt, column: 3)) ?? "",
                try self.decodeArray(Self.text(stmt, column: 4)) ?? [],
                Self.text(stmt, column: 5),
                Self.text(stmt, column: 6),
                GenerationMode(rawValue: Self.text(stmt, column: 7) ?? GenerationMode.sourceGroundedSummary.rawValue) ?? .sourceGroundedSummary,
                Self.date(stmt, column: 8) ?? Date(),
                Self.date(stmt, column: 9) ?? Date()
            )
        }
        return try baseRows.map { row in
            let itemIDs: [String] = try query(
                "SELECT item_id FROM research_artifact_items WHERE research_artifact_id = ? ORDER BY sort_order ASC",
                bindings: [.text(row.0)]
            ) { stmt in Self.text(stmt, column: 0) ?? "" }
            return ResearchArtifact(
                id: row.0,
                workspaceID: workspaceID,
                title: row.1,
                promptContext: row.2,
                summaryText: row.3,
                bulletSummary: row.4,
                modelName: row.5,
                modelVersion: row.6,
                generationMode: row.7,
                createdAt: row.8,
                updatedAt: row.9,
                itemIDs: itemIDs
            )
        }
    }

    public func saveExportRecord(_ record: ExportRecord) throws {
        let sql = "INSERT OR REPLACE INTO export_records (id, workspace_id, export_type, file_name, file_checksum, created_at, completed_at, format_version, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)"
        try execute(sql, bindings: [
            .text(record.id), .text(record.workspaceID), .text(record.exportType.rawValue), .text(record.fileName), .text(record.fileChecksum),
            .text(AmonCoders.storageDateFormatter.string(from: record.createdAt)),
            .text(record.completedAt.map { AmonCoders.storageDateFormatter.string(from: $0) }),
            .int(record.formatVersion), .text(record.status.rawValue)
        ])
    }

    public func buildWorkspaceGraph(workspaceID: String) throws -> WorkspaceGraph? {
        guard let workspace = try fetchWorkspace(id: workspaceID) else { return nil }
        return WorkspaceGraph(
            workspace: workspace,
            items: try fetchItems(workspaceID: workspaceID),
            notes: try fetchNotes(workspaceID: workspaceID),
            compareArtifacts: try fetchCompareArtifacts(workspaceID: workspaceID),
            researchArtifacts: try fetchResearchArtifacts(workspaceID: workspaceID)
        )
    }

    public func importWorkspaceGraph(_ graph: WorkspaceGraph) throws {
        try saveWorkspace(graph.workspace)
        try graph.items.forEach(saveItem)
        try graph.notes.forEach(saveNote)
        try graph.compareArtifacts.forEach(saveCompareArtifact)
        try graph.researchArtifacts.forEach(saveResearchArtifact)
    }

    private func fetchCompareRows(compareArtifactID: String) throws -> [CompareRow] {
        let rows: [(String, String, String, CompareRowType, Int)] = try query(
            "SELECT id, field_key, field_label, row_type, sort_order FROM compare_rows WHERE compare_artifact_id = ? ORDER BY sort_order ASC",
            bindings: [.text(compareArtifactID)]
        ) { stmt in
            (
                Self.text(stmt, column: 0) ?? UUID().uuidString,
                Self.text(stmt, column: 1) ?? "field",
                try self.fieldCipher.decrypt(Self.text(stmt, column: 2)) ?? "Field",
                CompareRowType(rawValue: Self.text(stmt, column: 3) ?? CompareRowType.text.rawValue) ?? .text,
                Self.int(stmt, column: 4)
            )
        }

        return try rows.map { row in
            let cells: [CompareCell] = try query(
                "SELECT id, item_id, value_text, value_json, created_at, updated_at FROM compare_cells WHERE compare_row_id = ? ORDER BY created_at ASC",
                bindings: [.text(row.0)]
            ) { stmt in
                CompareCell(
                    id: Self.text(stmt, column: 0) ?? UUID().uuidString,
                    compareRowID: row.0,
                    itemID: Self.text(stmt, column: 1) ?? "",
                    valueText: try self.fieldCipher.decrypt(Self.text(stmt, column: 2)),
                    valueJSON: try self.decodeJSONValue(Self.text(stmt, column: 3)),
                    createdAt: Self.date(stmt, column: 4) ?? Date(),
                    updatedAt: Self.date(stmt, column: 5) ?? Date()
                )
            }
            return CompareRow(
                id: row.0,
                compareArtifactID: compareArtifactID,
                fieldKey: row.1,
                fieldLabel: row.2,
                rowType: row.3,
                sortOrder: row.4,
                cells: cells
            )
        }
    }

    private func applyFileProtection(to url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
        }
    }

    private func execute(_ sql: String, bindings: [SQLiteValue] = []) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteStoreError.prepare(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(statement) }
        try bind(bindings, to: statement)
        let result = sqlite3_step(statement)
        guard result == SQLITE_DONE || result == SQLITE_ROW else {
            throw SQLiteStoreError.step(String(cString: sqlite3_errmsg(db)))
        }
    }

    private func query<T>(_ sql: String, bindings: [SQLiteValue] = [], map: (OpaquePointer?) throws -> T) throws -> [T] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteStoreError.prepare(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(statement) }
        try bind(bindings, to: statement)
        var rows: [T] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            rows.append(try map(statement))
        }
        return rows
    }

    private func bind(_ bindings: [SQLiteValue], to statement: OpaquePointer?) throws {
        for (index, value) in bindings.enumerated() {
            let position = Int32(index + 1)
            let result: Int32
            switch value {
            case .text(let text):
                if let text {
                    result = sqlite3_bind_text(statement, position, text, -1, SQLITE_TRANSIENT)
                } else {
                    result = sqlite3_bind_null(statement, position)
                }
            case .int(let int):
                result = sqlite3_bind_int(statement, position, Int32(int))
            }
            guard result == SQLITE_OK else {
                throw SQLiteStoreError.bind(String(cString: sqlite3_errmsg(db)))
            }
        }
    }

    private func encode<T: Encodable>(_ value: T?) throws -> String? {
        guard let value else { return nil }
        let data = try JSONEncoder.amon.encode(value)
        let json = String(decoding: data, as: UTF8.self)
        return try fieldCipher.encrypt(json)
    }

    private func decodeArray(_ value: String?) throws -> [String]? {
        guard let decrypted = try fieldCipher.decrypt(value) else { return nil }
        return try JSONDecoder.amon.decode([String].self, from: Data(decrypted.utf8))
    }

    private func decodeObject(_ value: String?) throws -> [String: JSONValue]? {
        guard let decrypted = try fieldCipher.decrypt(value) else { return nil }
        return try JSONDecoder.amon.decode([String: JSONValue].self, from: Data(decrypted.utf8))
    }

    private func decodeJSONValue(_ value: String?) throws -> JSONValue? {
        guard let decrypted = try fieldCipher.decrypt(value) else { return nil }
        return try JSONDecoder.amon.decode(JSONValue.self, from: Data(decrypted.utf8))
    }

    private static func text(_ statement: OpaquePointer?, column: Int32) -> String? {
        guard let raw = sqlite3_column_text(statement, column) else { return nil }
        return String(cString: raw)
    }

    private static func int(_ statement: OpaquePointer?, column: Int32) -> Int {
        Int(sqlite3_column_int(statement, column))
    }

    private static func date(_ statement: OpaquePointer?, column: Int32) -> Date? {
        guard let value = text(statement, column: column) else { return nil }
        return AmonCoders.storageDateFormatter.date(from: value)
    }
}
