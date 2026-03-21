import Foundation

public enum SourceKind: String, Codable, CaseIterable, Sendable {
    case searchResult = "search_result"
    case openedPage = "opened_page"
    case retrievedPage = "retrieved_page"
}

public enum ResultType: String, Codable, CaseIterable, Sendable {
    case webPage = "web_page"
    case article
    case place
    case product
}

public enum NoteScopeType: String, Codable, CaseIterable, Sendable {
    case workspace
    case item
    case compare
}

public enum CompareRowType: String, Codable, CaseIterable, Sendable {
    case text
    case number
    case bulletList = "bullet_list"
    case url
}

public enum GenerationMode: String, Codable, CaseIterable, Sendable {
    case sourceGroundedSummary = "source_grounded_summary"
}

public struct Workspace: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var description: String?
    public var colorTag: String?
    public var iconName: String?
    public var createdAt: Date
    public var updatedAt: Date
    public var lastOpenedAt: Date?
    public var isArchived: Bool
    public var exportVersion: Int
    public var localSchemaVersion: Int

    public init(
        id: String = UUID().uuidString,
        title: String,
        description: String? = nil,
        colorTag: String? = nil,
        iconName: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastOpenedAt: Date? = nil,
        isArchived: Bool = false,
        exportVersion: Int = 1,
        localSchemaVersion: Int = 1
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.colorTag = colorTag
        self.iconName = iconName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastOpenedAt = lastOpenedAt
        self.isArchived = isArchived
        self.exportVersion = exportVersion
        self.localSchemaVersion = localSchemaVersion
    }
}

public struct Item: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var workspaceID: String
    public var sourceKind: SourceKind
    public var resultType: ResultType
    public var title: String
    public var canonicalURL: String
    public var domain: String
    public var snippet: String?
    public var pageTitle: String?
    public var cleanedExcerpt: String?
    public var bulletPoints: [String]
    public var providerName: String?
    public var providerResultID: String?
    public var fetchedAt: Date?
    public var savedAt: Date
    public var updatedAt: Date
    public var typedMetadata: [String: JSONValue]
    public var sourceMetadata: [String: JSONValue]
    public var contentHash: String?
    public var isDeleted: Bool

    public init(
        id: String = UUID().uuidString,
        workspaceID: String,
        sourceKind: SourceKind,
        resultType: ResultType,
        title: String,
        canonicalURL: String,
        domain: String,
        snippet: String? = nil,
        pageTitle: String? = nil,
        cleanedExcerpt: String? = nil,
        bulletPoints: [String] = [],
        providerName: String? = nil,
        providerResultID: String? = nil,
        fetchedAt: Date? = nil,
        savedAt: Date = Date(),
        updatedAt: Date = Date(),
        typedMetadata: [String: JSONValue] = [:],
        sourceMetadata: [String: JSONValue] = [:],
        contentHash: String? = nil,
        isDeleted: Bool = false
    ) {
        self.id = id
        self.workspaceID = workspaceID
        self.sourceKind = sourceKind
        self.resultType = resultType
        self.title = title
        self.canonicalURL = canonicalURL
        self.domain = domain
        self.snippet = snippet
        self.pageTitle = pageTitle
        self.cleanedExcerpt = cleanedExcerpt
        self.bulletPoints = bulletPoints
        self.providerName = providerName
        self.providerResultID = providerResultID
        self.fetchedAt = fetchedAt
        self.savedAt = savedAt
        self.updatedAt = updatedAt
        self.typedMetadata = typedMetadata
        self.sourceMetadata = sourceMetadata
        self.contentHash = contentHash
        self.isDeleted = isDeleted
    }
}

public struct Note: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var workspaceID: String?
    public var itemID: String?
    public var compareArtifactID: String?
    public var scopeType: NoteScopeType
    public var body: String
    public var createdAt: Date
    public var updatedAt: Date
    public var isDeleted: Bool

    public init(
        id: String = UUID().uuidString,
        workspaceID: String? = nil,
        itemID: String? = nil,
        compareArtifactID: String? = nil,
        scopeType: NoteScopeType,
        body: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isDeleted: Bool = false
    ) {
        self.id = id
        self.workspaceID = workspaceID
        self.itemID = itemID
        self.compareArtifactID = compareArtifactID
        self.scopeType = scopeType
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
    }
}

public struct CompareCell: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var compareRowID: String
    public var itemID: String
    public var valueText: String?
    public var valueJSON: JSONValue?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        compareRowID: String,
        itemID: String,
        valueText: String? = nil,
        valueJSON: JSONValue? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.compareRowID = compareRowID
        self.itemID = itemID
        self.valueText = valueText
        self.valueJSON = valueJSON
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct CompareRow: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var compareArtifactID: String
    public var fieldKey: String
    public var fieldLabel: String
    public var rowType: CompareRowType
    public var sortOrder: Int
    public var cells: [CompareCell]

    public init(
        id: String = UUID().uuidString,
        compareArtifactID: String,
        fieldKey: String,
        fieldLabel: String,
        rowType: CompareRowType,
        sortOrder: Int,
        cells: [CompareCell] = []
    ) {
        self.id = id
        self.compareArtifactID = compareArtifactID
        self.fieldKey = fieldKey
        self.fieldLabel = fieldLabel
        self.rowType = rowType
        self.sortOrder = sortOrder
        self.cells = cells
    }
}

public struct CompareArtifact: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var workspaceID: String
    public var title: String
    public var summary: String?
    public var compareSchemaVersion: Int
    public var createdAt: Date
    public var updatedAt: Date
    public var itemIDs: [String]
    public var rows: [CompareRow]

    public init(
        id: String = UUID().uuidString,
        workspaceID: String,
        title: String,
        summary: String? = nil,
        compareSchemaVersion: Int = 1,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        itemIDs: [String] = [],
        rows: [CompareRow] = []
    ) {
        self.id = id
        self.workspaceID = workspaceID
        self.title = title
        self.summary = summary
        self.compareSchemaVersion = compareSchemaVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.itemIDs = itemIDs
        self.rows = rows
    }
}

public struct ResearchArtifact: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var workspaceID: String
    public var title: String
    public var promptContext: String?
    public var summaryText: String
    public var bulletSummary: [String]
    public var modelName: String?
    public var modelVersion: String?
    public var generationMode: GenerationMode
    public var createdAt: Date
    public var updatedAt: Date
    public var itemIDs: [String]

    public init(
        id: String = UUID().uuidString,
        workspaceID: String,
        title: String,
        promptContext: String? = nil,
        summaryText: String,
        bulletSummary: [String] = [],
        modelName: String? = nil,
        modelVersion: String? = nil,
        generationMode: GenerationMode = .sourceGroundedSummary,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        itemIDs: [String] = []
    ) {
        self.id = id
        self.workspaceID = workspaceID
        self.title = title
        self.promptContext = promptContext
        self.summaryText = summaryText
        self.bulletSummary = bulletSummary
        self.modelName = modelName
        self.modelVersion = modelVersion
        self.generationMode = generationMode
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.itemIDs = itemIDs
    }
}

public struct ExportRecord: Codable, Equatable, Identifiable, Sendable {
    public enum ExportType: String, Codable, Sendable {
        case workspaceExport = "workspace_export"
        case workspaceImport = "workspace_import"
    }

    public enum Status: String, Codable, Sendable {
        case started
        case completed
        case failed
    }

    public var id: String
    public var workspaceID: String
    public var exportType: ExportType
    public var fileName: String?
    public var fileChecksum: String?
    public var createdAt: Date
    public var completedAt: Date?
    public var formatVersion: Int
    public var status: Status

    public init(
        id: String = UUID().uuidString,
        workspaceID: String,
        exportType: ExportType,
        fileName: String? = nil,
        fileChecksum: String? = nil,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        formatVersion: Int = 1,
        status: Status
    ) {
        self.id = id
        self.workspaceID = workspaceID
        self.exportType = exportType
        self.fileName = fileName
        self.fileChecksum = fileChecksum
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.formatVersion = formatVersion
        self.status = status
    }
}

public struct WorkspaceGraph: Codable, Equatable, Sendable {
    public var formatVersion: Int
    public var exportedAt: Date
    public var workspace: Workspace
    public var items: [Item]
    public var notes: [Note]
    public var compareArtifacts: [CompareArtifact]
    public var researchArtifacts: [ResearchArtifact]

    public init(
        formatVersion: Int = 1,
        exportedAt: Date = Date(),
        workspace: Workspace,
        items: [Item],
        notes: [Note],
        compareArtifacts: [CompareArtifact],
        researchArtifacts: [ResearchArtifact]
    ) {
        self.formatVersion = formatVersion
        self.exportedAt = exportedAt
        self.workspace = workspace
        self.items = items
        self.notes = notes
        self.compareArtifacts = compareArtifacts
        self.researchArtifacts = researchArtifacts
    }
}

public struct SearchSessionState: Equatable, Sendable {
    public var query: String = ""
    public var results: [SearchResult] = []
    public var selectedResultIDs: Set<String> = []
}

public struct OpenPageSession: Equatable, Sendable {
    public var url: URL
    public var cleanViewEnabled: Bool

    public init(url: URL, cleanViewEnabled: Bool = false) {
        self.url = url
        self.cleanViewEnabled = cleanViewEnabled
    }
}

public struct CompareDraft: Equatable, Sendable {
    public var title: String
    public var items: [Item]

    public init(title: String, items: [Item]) {
        self.title = title
        self.items = items
    }
}

public struct ResearchDraft: Equatable, Sendable {
    public var title: String
    public var promptContext: String?
    public var items: [Item]

    public init(title: String, promptContext: String? = nil, items: [Item]) {
        self.title = title
        self.promptContext = promptContext
        self.items = items
    }
}
