import Foundation
import SwiftUI

@MainActor
public final class SearchViewModel: ObservableObject {
    @Published public var query: String = ""
    @Published public var results: [SearchResult] = []
    @Published public var selectedResultIDs: Set<String> = []
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    @Published public var activeCompare: CompareArtifact?
    @Published public var activeResearch: ResearchArtifact?
    @Published public var currentWorkspace: Workspace?
    @Published public var isAuthenticated: Bool = false

    private let apiClient: AmonAPIClient
    private let store: WorkspaceStore

    public init(apiClient: AmonAPIClient, store: WorkspaceStore) {
        self.apiClient = apiClient
        self.store = store
        self.currentWorkspace = try? store.fetchWorkspaces().first
    }

    public func completeAppleDevSignIn(subject: String) async {
        do {
            _ = try await apiClient.devLogin(appleSubject: subject)
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func search() async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            results = try await apiClient.search(query: query, count: 10)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func ensureWorkspace(title: String = "Saved") throws -> Workspace {
        if let currentWorkspace {
            return currentWorkspace
        }
        let workspace = try store.createWorkspace(title: title, description: nil)
        currentWorkspace = workspace
        return workspace
    }

    public func save(result: SearchResult) {
        do {
            let workspace = try ensureWorkspace()
            let item = result.toItem(workspaceID: workspace.id)
            try store.saveItem(item)
            currentWorkspace = try store.fetchWorkspace(id: workspace.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func saveSelectedResults() {
        let selected = results.filter { selectedResultIDs.contains($0.id) }
        selected.forEach(save(result:))
    }

    public func selectedItems() throws -> [Item] {
        let workspace = try ensureWorkspace()
        let savedItems = try store.fetchItems(workspaceID: workspace.id)
        let selectedURLs = Set(results.filter { selectedResultIDs.contains($0.id) }.map(\.url))
        return savedItems.filter { selectedURLs.contains($0.canonicalURL) }
    }

    public func retrieveAndRefresh(item: Item) async -> Item? {
        do {
            let retrieved = try await apiClient.retrieve(url: item.canonicalURL)
            let updated = retrieved.merged(into: item)
            try store.saveItem(updated)
            return updated
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    public func runCompare() async {
        do {
            let workspace = try ensureWorkspace()
            let items = try selectedItems()
            guard items.count >= 2 else {
                errorMessage = "Select at least two saved items."
                return
            }
            let response = try await apiClient.compare(title: "Compare", items: items)
            var rows: [CompareRow] = []
            for (rowIndex, row) in response.rows.enumerated() {
                let rowID = UUID().uuidString
                let cells = row.cells.map {
                    CompareCell(
                        compareRowID: rowID,
                        itemID: $0.item_id ?? "",
                        valueText: $0.value_text,
                        valueJSON: $0.value_json
                    )
                }
                rows.append(
                    CompareRow(
                        id: rowID,
                        compareArtifactID: "",
                        fieldKey: row.field_key,
                        fieldLabel: row.field_label,
                        rowType: row.row_type,
                        sortOrder: rowIndex,
                        cells: cells
                    )
                )
            }
            let artifactID = UUID().uuidString
            rows = rows.map { row in
                var mutable = row
                mutable.compareArtifactID = artifactID
                mutable.cells = row.cells.map { cell in
                    var mutableCell = cell
                    mutableCell.compareRowID = mutable.id
                    return mutableCell
                }
                return mutable
            }
            let artifact = CompareArtifact(
                id: artifactID,
                workspaceID: workspace.id,
                title: response.title,
                summary: response.summary,
                itemIDs: items.map(\.id),
                rows: rows
            )
            try store.saveCompareArtifact(artifact)
            activeCompare = artifact
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func runResearch(promptContext: String? = nil) async {
        do {
            let workspace = try ensureWorkspace()
            let items = try selectedItems()
            guard items.count >= 2 else {
                errorMessage = "Select at least two saved items."
                return
            }
            let response = try await apiClient.research(title: "Research", promptContext: promptContext, items: items)
            let artifact = ResearchArtifact(
                workspaceID: workspace.id,
                title: response.title,
                promptContext: promptContext,
                summaryText: response.summary_text,
                bulletSummary: response.bullet_summary,
                modelName: response.model.name,
                modelVersion: response.model.version,
                itemIDs: items.map(\.id)
            )
            try store.saveResearchArtifact(artifact)
            activeResearch = artifact
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
