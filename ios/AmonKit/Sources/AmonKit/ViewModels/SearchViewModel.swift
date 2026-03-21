import Foundation
import SwiftUI

private enum SearchFlowError: Error {
    case materializationFailed
}

@MainActor
public final class SearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published private(set) var results: [SearchResult] = []
    @Published private(set) var selectedResultIDs: Set<String> = []
    @Published private(set) var savedResultIDs: Set<String> = []
    @Published private(set) var hasSearched: Bool = false
    @Published private(set) var isSearching: Bool = false
    @Published private(set) var isSigningIn: Bool = false
    @Published private(set) var isSavingLocally: Bool = false
    @Published private(set) var isRunningCompare: Bool = false
    @Published private(set) var isRunningResearch: Bool = false
    @Published private(set) var currentWorkspace: Workspace?
    @Published public private(set) var isRestoringSession: Bool = false
    @Published public private(set) var isAuthenticated: Bool = false
    @Published var banner: AmonBanner?
    @Published var activePresentation: SearchPresentation?

    private let apiClient: any AmonAPIClienting
    private let store: WorkspaceStore
    private var didAttemptSessionRestore = false
    private var workspaceDidChangeHandler: (@MainActor () -> Void)?
    private let defaultWorkspaceTitle = "Research Library"

    public init(apiClient: any AmonAPIClienting, store: WorkspaceStore) {
        self.apiClient = apiClient
        self.store = store
        refreshWorkspaceState()
    }

    public func setWorkspaceDidChangeHandler(_ handler: @escaping @MainActor () -> Void) {
        workspaceDidChangeHandler = handler
    }

    public func restoreSessionIfNeeded() async {
        guard !didAttemptSessionRestore else { return }
        didAttemptSessionRestore = true
        isRestoringSession = true
        defer { isRestoringSession = false }

        do {
            _ = try await apiClient.me()
            isAuthenticated = true
            banner = nil
        } catch {
            if AmonErrorPresenter.isUnauthorized(error) {
                signOut(silent: true)
            } else {
                banner = AmonBanner(
                    tone: .error,
                    title: "Connection issue",
                    message: AmonErrorPresenter.message(
                        for: error,
                        fallback: "Amon couldn't validate your current session."
                    )
                )
            }
        }
    }

    func signIn(appleSubject: String) async {
        guard !isSigningIn else { return }
        isSigningIn = true
        banner = nil
        defer { isSigningIn = false }

        do {
            _ = try await apiClient.devLogin(appleSubject: appleSubject)
            isAuthenticated = true
            banner = nil
            refreshWorkspaceState()
        } catch {
            banner = AmonBanner(
                tone: .error,
                title: "Couldn't sign in",
                message: AmonErrorPresenter.message(for: error, fallback: "Amon couldn't complete sign in.")
            )
        }
    }

    func dismissBanner() {
        banner = nil
    }

    func search() async {
        guard !isSearching else { return }

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            banner = AmonBanner(
                tone: .info,
                title: "Start with a query",
                message: "Enter something to search, compare, or save locally."
            )
            return
        }

        isSearching = true
        hasSearched = true
        banner = nil
        selectedResultIDs.removeAll()
        results = []
        savedResultIDs.removeAll()
        defer { isSearching = false }

        do {
            results = try await apiClient.search(query: trimmedQuery, count: 10)
            reconcileSelection()
            refreshSavedResultIDs()
        } catch {
            handleRemoteError(
                error,
                title: "Search unavailable",
                fallback: "Amon couldn't load results right now."
            )
        }
    }

    func toggleSelection(for resultID: String) {
        guard results.contains(where: { $0.id == resultID }) else { return }
        if selectedResultIDs.contains(resultID) {
            selectedResultIDs.remove(resultID)
        } else {
            selectedResultIDs.insert(resultID)
        }
    }

    func save(result: SearchResult) {
        guard !isSavingLocally else { return }
        _ = persist(results: [result], announce: true)
    }

    func saveSelectedResults() {
        guard !isSavingLocally else { return }
        _ = persist(results: selectedResults, announce: true)
    }

    func runCompare() async {
        guard !isRunningCompare else { return }
        guard selectedResults.count >= 2 else {
            banner = AmonBanner(
                tone: .info,
                title: "Select at least two results",
                message: "Compare works best when you choose two or more saved sources."
            )
            return
        }

        isRunningCompare = true
        banner = nil
        defer { isRunningCompare = false }

        do {
            let items = try materializeSelectedItems()
            let response = try await apiClient.compare(title: "Compare", items: items)
            let artifact = buildCompareArtifact(
                from: response,
                workspaceID: items.first?.workspaceID ?? "",
                itemIDs: items.map(\.id)
            )
            try store.saveCompareArtifact(artifact)
            refreshWorkspaceState()
            notifyWorkspaceDidChange()
            activePresentation = .compare(artifact, items)
        } catch {
            if error is SearchFlowError { return }
            handleRemoteError(
                error,
                title: "Compare unavailable",
                fallback: "Amon couldn't build that compare view."
            )
        }
    }

    func runResearch(promptContext: String? = nil) async {
        guard !isRunningResearch else { return }
        guard selectedResults.count >= 2 else {
            banner = AmonBanner(
                tone: .info,
                title: "Select at least two results",
                message: "Research mode needs at least two sources to synthesize."
            )
            return
        }

        isRunningResearch = true
        banner = nil
        defer { isRunningResearch = false }

        do {
            let items = try materializeSelectedItems()
            let response = try await apiClient.research(title: "Research", promptContext: promptContext, items: items)
            let artifact = ResearchArtifact(
                workspaceID: items.first?.workspaceID ?? "",
                title: response.title,
                promptContext: promptContext,
                summaryText: response.summary_text,
                bulletSummary: response.bullet_summary,
                modelName: response.model.name,
                modelVersion: response.model.version,
                itemIDs: items.map(\.id)
            )
            try store.saveResearchArtifact(artifact)
            refreshWorkspaceState()
            notifyWorkspaceDidChange()
            activePresentation = .research(artifact, items)
        } catch {
            if error is SearchFlowError { return }
            handleRemoteError(
                error,
                title: "Research unavailable",
                fallback: "Amon couldn't build that research summary."
            )
        }
    }

    func dismissPresentation() {
        activePresentation = nil
    }

    func isSelected(_ result: SearchResult) -> Bool {
        selectedResultIDs.contains(result.id)
    }

    func isSaved(_ result: SearchResult) -> Bool {
        savedResultIDs.contains(result.id)
    }

    var selectedResults: [SearchResult] {
        results.filter { selectedResultIDs.contains($0.id) }
    }

    var selectedCount: Int {
        selectedResults.count
    }

    var shouldShowSelectionBar: Bool {
        selectedCount > 0
    }

    var canSubmitSearch: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isSearching
            && !isSigningIn
            && !isRunningCompare
            && !isRunningResearch
            && !isRestoringSession
    }

    var canSaveSelection: Bool {
        selectedCount > 0 && !isSavingLocally && !isRunningCompare && !isRunningResearch && !isSearching
    }

    var canCompare: Bool {
        selectedCount >= 2 && !isRunningCompare && !isRunningResearch && !isSavingLocally
    }

    var canResearch: Bool {
        selectedCount >= 2 && !isRunningResearch && !isRunningCompare && !isSavingLocally
    }

    func retrieveAndRefresh(item: Item) async -> Item? {
        do {
            let retrieved = try await apiClient.retrieve(url: item.canonicalURL)
            let updated = retrieved.merged(into: item)
            try store.saveItem(updated)
            refreshWorkspaceState()
            notifyWorkspaceDidChange()
            return updated
        } catch {
            banner = AmonBanner(
                tone: .error,
                title: "Couldn't refresh page",
                message: AmonErrorPresenter.message(for: error, fallback: "Amon couldn't refresh that saved page.")
            )
            return nil
        }
    }

    private func persist(results: [SearchResult], announce: Bool) -> [Item]? {
        let uniqueResults = deduplicated(results: results)
        guard !uniqueResults.isEmpty else {
            if announce {
                banner = AmonBanner(
                    tone: .info,
                    title: "Nothing selected",
                    message: "Choose one or more results to save locally."
                )
            }
            return nil
        }

        isSavingLocally = true
        defer { isSavingLocally = false }

        do {
            let workspace = try ensureWorkspace()
            let existingItems = try store.fetchItems(workspaceID: workspace.id)
            var itemsByURL = Dictionary(uniqueKeysWithValues: existingItems.map { ($0.canonicalURL, $0) })
            var persistedItems: [Item] = []
            var newItemCount = 0

            for result in uniqueResults {
                let wasExisting = itemsByURL[result.url] != nil
                let item = try upsertItem(result: result, workspace: workspace, itemsByURL: &itemsByURL)
                if !wasExisting { newItemCount += 1 }
                persistedItems.append(item)
            }

            refreshWorkspaceState()
            notifyWorkspaceDidChange()

            if announce {
                banner = saveConfirmationBanner(
                    totalCount: uniqueResults.count,
                    newItemCount: newItemCount,
                    workspaceTitle: currentWorkspace?.title ?? workspace.title
                )
            }

            return persistedItems
        } catch {
            banner = AmonBanner(
                tone: .error,
                title: "Couldn't save locally",
                message: AmonErrorPresenter.message(for: error, fallback: "Amon couldn't save that result to your device.")
            )
            return nil
        }
    }

    private func materializeSelectedItems() throws -> [Item] {
        if let items = persist(results: selectedResults, announce: false), items.count >= 2 {
            return items
        }
        throw SearchFlowError.materializationFailed
    }

    private func ensureWorkspace(title: String? = nil) throws -> Workspace {
        refreshWorkspaceState()
        if let currentWorkspace {
            return currentWorkspace
        }
        let workspace = try store.createWorkspace(title: title ?? defaultWorkspaceTitle, description: nil)
        currentWorkspace = workspace
        return workspace
    }

    private func refreshWorkspaceState() {
        do {
            let workspaces = try store.fetchWorkspaces()
            if let existingWorkspace = currentWorkspace {
                currentWorkspace = workspaces.first(where: { $0.id == existingWorkspace.id }) ?? workspaces.first
            } else {
                currentWorkspace = workspaces.first
            }
            refreshSavedResultIDs()
        } catch {
            currentWorkspace = nil
            savedResultIDs = []
        }
    }

    private func refreshSavedResultIDs() {
        guard let workspace = currentWorkspace else {
            savedResultIDs = []
            return
        }
        let savedItems = (try? store.fetchItems(workspaceID: workspace.id)) ?? []
        let savedURLs = Set(savedItems.map(\.canonicalURL))
        savedResultIDs = Set(results.filter { savedURLs.contains($0.url) }.map(\.id))
    }

    private func deduplicated(results: [SearchResult]) -> [SearchResult] {
        var seen = Set<String>()
        return results.filter { result in
            seen.insert(result.url).inserted
        }
    }

    private func upsertItem(
        result: SearchResult,
        workspace: Workspace,
        itemsByURL: inout [String: Item]
    ) throws -> Item {
        var item = itemsByURL[result.url] ?? result.toItem(workspaceID: workspace.id)
        item.workspaceID = workspace.id
        item.resultType = result.result_type
        item.title = result.title
        item.canonicalURL = result.url
        item.domain = result.domain
        item.snippet = result.snippet
        item.providerName = result.provider.name
        item.providerResultID = result.provider.provider_result_id
        item.typedMetadata = result.typed_metadata ?? [:]
        item.updatedAt = Date()
        try store.saveItem(item)
        itemsByURL[result.url] = item
        return item
    }

    private func reconcileSelection() {
        let validIDs = Set(results.map(\.id))
        selectedResultIDs = selectedResultIDs.intersection(validIDs)
    }

    private func buildCompareArtifact(
        from response: CompareResponseDTO,
        workspaceID: String,
        itemIDs: [String]
    ) -> CompareArtifact {
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

        return CompareArtifact(
            id: artifactID,
            workspaceID: workspaceID,
            title: response.title,
            summary: response.summary,
            itemIDs: itemIDs,
            rows: rows
        )
    }

    private func saveConfirmationBanner(totalCount: Int, newItemCount: Int, workspaceTitle: String) -> AmonBanner {
        if newItemCount == 0 {
            return AmonBanner(
                tone: .info,
                title: "Already saved",
                message: totalCount == 1
                    ? "That source is already saved locally in \(workspaceTitle)."
                    : "Those sources are already saved locally in \(workspaceTitle)."
            )
        }

        return AmonBanner(
            tone: .success,
            title: "Saved locally",
            message: totalCount == 1
                ? "Added to \(workspaceTitle). No server history is kept."
                : "Saved \(newItemCount) source\(newItemCount == 1 ? "" : "s") to \(workspaceTitle)."
        )
    }

    private func notifyWorkspaceDidChange() {
        workspaceDidChangeHandler?()
    }

    private func handleRemoteError(_ error: Error, title: String, fallback: String) {
        if AmonErrorPresenter.isUnauthorized(error) {
            signOut(
                silent: false,
                message: "Your session ended. Sign in again to keep searching and saving locally."
            )
            return
        }

        banner = AmonBanner(
            tone: .error,
            title: title,
            message: AmonErrorPresenter.message(for: error, fallback: fallback)
        )
    }

    private func signOut(silent: Bool, message: String? = nil) {
        try? apiClient.clearSession()
        isAuthenticated = false
        selectedResultIDs.removeAll()
        activePresentation = nil
        if silent {
            banner = nil
        } else if let message {
            banner = AmonBanner(tone: .info, title: "Sign in again", message: message)
        }
    }
}
