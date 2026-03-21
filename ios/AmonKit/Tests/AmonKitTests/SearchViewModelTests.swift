import XCTest
@testable import AmonKit

@MainActor
final class SearchViewModelTests: XCTestCase {
    func testSearchLoadsResultsAndMarksSavedItems() async throws {
        let store = MockWorkspaceStore()
        let workspace = try store.createWorkspace(title: "Research Library", description: nil)
        try store.saveItem(
            Item(
                workspaceID: workspace.id,
                sourceKind: .searchResult,
                resultType: .article,
                title: "Existing",
                canonicalURL: "https://example.com/one",
                domain: "example.com"
            )
        )

        let api = MockAPIClient()
        api.searchResults = [
            makeResult(id: "one", title: "One", url: "https://example.com/one"),
            makeResult(id: "two", title: "Two", url: "https://example.com/two"),
        ]

        let viewModel = SearchViewModel(apiClient: api, store: store)
        viewModel.query = "privacy"

        await viewModel.search()

        XCTAssertEqual(api.searchRequests.count, 1)
        XCTAssertEqual(api.searchRequests.first?.0, "privacy")
        XCTAssertEqual(api.searchRequests.first?.1, 10)
        XCTAssertEqual(viewModel.results.count, 2)
        XCTAssertTrue(viewModel.isSaved(api.searchResults[0]))
        XCTAssertFalse(viewModel.isSaved(api.searchResults[1]))
    }

    func testSaveSelectedResultsDeduplicatesByURL() async throws {
        let store = MockWorkspaceStore()
        let api = MockAPIClient()
        api.searchResults = [makeResult(id: "one", title: "One", url: "https://example.com/one")]

        let viewModel = SearchViewModel(apiClient: api, store: store)
        viewModel.query = "privacy"
        await viewModel.search()

        viewModel.toggleSelection(for: "one")
        viewModel.saveSelectedResults()
        viewModel.saveSelectedResults()

        let workspace = try XCTUnwrap(store.fetchWorkspaces().first)
        let items = try store.fetchItems(workspaceID: workspace.id)
        XCTAssertEqual(items.count, 1)
        XCTAssertTrue(viewModel.isSaved(api.searchResults[0]))
    }

    func testRunCompareMaterializesSelectedItemsAndPresentsCompare() async throws {
        let store = MockWorkspaceStore()
        let api = MockAPIClient()
        api.searchResults = [
            makeResult(id: "one", title: "One", url: "https://example.com/one"),
            makeResult(id: "two", title: "Two", url: "https://example.com/two"),
        ]
        api.compareResponse = CompareResponseDTO(
            title: "Compare",
            summary: "Compared two sources.",
            rows: [
                CompareRowDTO(
                    field_key: "title",
                    field_label: "Title",
                    row_type: .text,
                    cells: [
                        CompareCellDTO(item_id: "item-one", value_text: "One", value_json: nil),
                        CompareCellDTO(item_id: "item-two", value_text: "Two", value_json: nil),
                    ]
                )
            ]
        )

        let viewModel = SearchViewModel(apiClient: api, store: store)
        viewModel.query = "privacy"
        await viewModel.search()
        viewModel.toggleSelection(for: "one")
        viewModel.toggleSelection(for: "two")

        await viewModel.runCompare()

        let workspace = try XCTUnwrap(store.fetchWorkspaces().first)
        XCTAssertEqual(try store.fetchItems(workspaceID: workspace.id).count, 2)
        XCTAssertEqual(try store.fetchCompareArtifacts(workspaceID: workspace.id).count, 1)

        guard case .compare(let artifact, let items)? = viewModel.activePresentation else {
            return XCTFail("Expected compare presentation")
        }

        XCTAssertEqual(artifact.title, "Compare")
        XCTAssertEqual(items.count, 2)
    }

    func testUnauthorizedSearchReturnsUserToAuthFlow() async {
        let store = MockWorkspaceStore()
        let api = MockAPIClient()
        api.searchError = AmonAPIError.unauthorized

        let viewModel = SearchViewModel(apiClient: api, store: store)
        await viewModel.signIn(appleSubject: "dev-user")
        viewModel.query = "privacy"

        await viewModel.search()

        XCTAssertFalse(viewModel.isAuthenticated)
        XCTAssertEqual(api.clearSessionCalls, 1)
        XCTAssertEqual(viewModel.banner?.title, "Sign in again")
    }

    private func makeResult(id: String, title: String, url: String) -> SearchResult {
        SearchResult(
            id: id,
            title: title,
            url: url,
            snippet: "Snippet",
            result_type: .article,
            domain: "example.com",
            typed_metadata: ["age": .string("Today")],
            provider: ProviderInfoDTO(name: "brave", provider_result_id: id)
        )
    }
}

private final class MockAPIClient: @unchecked Sendable, AmonAPIClienting {
    var searchResults: [SearchResult] = []
    var searchError: Error?
    var compareResponse = CompareResponseDTO(title: "Compare", summary: "Summary", rows: [])
    var researchResponse = ResearchResponseDTO(
        title: "Research",
        summary_text: "Summary",
        bullet_summary: [],
        sources: [],
        model: ModelInfoDTO(name: "mock", version: "1")
    )
    var searchRequests: [(String, Int)] = []
    var clearSessionCalls = 0

    func devLogin(appleSubject: String) async throws -> AuthResponseDTO {
        AuthResponseDTO(
            access_token: "token",
            token_type: "bearer",
            expires_at: Date().ISO8601Format(),
            user: UserDTO(id: "user_1", status: "active", entitlement_tier: "full_access", entitlement_status: "active")
        )
    }

    func me() async throws -> UserDTO {
        UserDTO(id: "user_1", status: "active", entitlement_tier: "full_access", entitlement_status: "active")
    }

    func search(query: String, count: Int) async throws -> [SearchResult] {
        searchRequests.append((query, count))
        if let searchError {
            throw searchError
        }
        return searchResults
    }

    func retrieve(url: String) async throws -> StructuredRetrievalDTO {
        StructuredRetrievalDTO(
            url: url,
            canonical_url: url,
            title: "Title",
            domain: "example.com",
            excerpt: nil,
            bullet_points: [],
            retrieved_at: Date()
        )
    }

    func compare(title: String, items: [Item]) async throws -> CompareResponseDTO {
        compareResponse
    }

    func research(title: String, promptContext: String?, items: [Item]) async throws -> ResearchResponseDTO {
        researchResponse
    }

    func clearSession() throws {
        clearSessionCalls += 1
    }
}

private final class MockWorkspaceStore: WorkspaceStore {
    private var workspaces: [Workspace] = []
    private var items: [Item] = []
    private var notes: [Note] = []
    private var compareArtifacts: [CompareArtifact] = []
    private var researchArtifacts: [ResearchArtifact] = []
    private var exportRecords: [ExportRecord] = []

    func createWorkspace(title: String, description: String?) throws -> Workspace {
        let workspace = Workspace(title: title, description: description)
        workspaces.append(workspace)
        return workspace
    }

    func saveWorkspace(_ workspace: Workspace) throws {
        if let index = workspaces.firstIndex(where: { $0.id == workspace.id }) {
            workspaces[index] = workspace
        } else {
            workspaces.append(workspace)
        }
    }

    func fetchWorkspaces() throws -> [Workspace] {
        workspaces.sorted(by: { $0.updatedAt > $1.updatedAt })
    }

    func fetchWorkspace(id: String) throws -> Workspace? {
        workspaces.first(where: { $0.id == id })
    }

    func saveItem(_ item: Item) throws {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.append(item)
        }
    }

    func fetchItems(workspaceID: String) throws -> [Item] {
        items.filter { $0.workspaceID == workspaceID }
    }

    func saveNote(_ note: Note) throws {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index] = note
        } else {
            notes.append(note)
        }
    }

    func fetchNotes(workspaceID: String) throws -> [Note] {
        notes.filter { $0.workspaceID == workspaceID }
    }

    func saveCompareArtifact(_ artifact: CompareArtifact) throws {
        if let index = compareArtifacts.firstIndex(where: { $0.id == artifact.id }) {
            compareArtifacts[index] = artifact
        } else {
            compareArtifacts.append(artifact)
        }
    }

    func fetchCompareArtifacts(workspaceID: String) throws -> [CompareArtifact] {
        compareArtifacts.filter { $0.workspaceID == workspaceID }
    }

    func saveResearchArtifact(_ artifact: ResearchArtifact) throws {
        if let index = researchArtifacts.firstIndex(where: { $0.id == artifact.id }) {
            researchArtifacts[index] = artifact
        } else {
            researchArtifacts.append(artifact)
        }
    }

    func fetchResearchArtifacts(workspaceID: String) throws -> [ResearchArtifact] {
        researchArtifacts.filter { $0.workspaceID == workspaceID }
    }

    func saveExportRecord(_ record: ExportRecord) throws {
        exportRecords.append(record)
    }

    func buildWorkspaceGraph(workspaceID: String) throws -> WorkspaceGraph? {
        guard let workspace = try fetchWorkspace(id: workspaceID) else { return nil }
        return WorkspaceGraph(
            workspace: workspace,
            items: try fetchItems(workspaceID: workspaceID),
            notes: try fetchNotes(workspaceID: workspaceID),
            compareArtifacts: try fetchCompareArtifacts(workspaceID: workspaceID),
            researchArtifacts: try fetchResearchArtifacts(workspaceID: workspaceID)
        )
    }

    func importWorkspaceGraph(_ graph: WorkspaceGraph) throws {
        try saveWorkspace(graph.workspace)
        try graph.items.forEach(saveItem)
        try graph.notes.forEach(saveNote)
        try graph.compareArtifacts.forEach(saveCompareArtifact)
        try graph.researchArtifacts.forEach(saveResearchArtifact)
    }
}
