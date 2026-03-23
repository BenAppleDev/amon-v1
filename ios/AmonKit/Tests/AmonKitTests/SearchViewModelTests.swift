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

        let viewModel = SearchViewModel(
            apiClient: api,
            store: store,
            privacySettingsStore: makePrivacyStore(),
            userDefaults: makeSessionDefaults(),
            preferredWorkspaceStorageKey: "preferredWorkspace"
        )
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

        let viewModel = SearchViewModel(
            apiClient: api,
            store: store,
            privacySettingsStore: makePrivacyStore(),
            userDefaults: makeSessionDefaults(),
            preferredWorkspaceStorageKey: "preferredWorkspace"
        )
        viewModel.query = "privacy"
        await viewModel.search()

        XCTAssertTrue(viewModel.createWorkspace(title: "Research Library"))
        viewModel.toggleSelection(for: "one")
        viewModel.saveSelectedResults()
        viewModel.saveSelectedResults()

        let workspace = try XCTUnwrap(store.fetchWorkspaces().first)
        let items = try store.fetchItems(workspaceID: workspace.id)
        XCTAssertEqual(items.count, 1)
        XCTAssertTrue(viewModel.isSaved(api.searchResults[0]))
    }

    func testSaveRequiresExplicitWorkspaceSelectionWhenMultipleWorkspacesExist() async throws {
        let store = MockWorkspaceStore()
        _ = try store.createWorkspace(title: "Workspace A", description: nil)
        _ = try store.createWorkspace(title: "Workspace B", description: nil)

        let api = MockAPIClient()
        api.searchResults = [makeResult(id: "one", title: "One", url: "https://example.com/one")]

        let viewModel = SearchViewModel(
            apiClient: api,
            store: store,
            privacySettingsStore: makePrivacyStore(),
            userDefaults: makeSessionDefaults(),
            preferredWorkspaceStorageKey: "preferredWorkspace"
        )
        viewModel.query = "privacy"
        await viewModel.search()
        viewModel.toggleSelection(for: "one")

        viewModel.saveSelectedResults()

        XCTAssertNil(viewModel.currentWorkspace)
        XCTAssertEqual(viewModel.banner?.title, "Choose a workspace first")
        var savedItems: [Item] = []
        for workspace in try store.fetchWorkspaces() {
            savedItems.append(contentsOf: try store.fetchItems(workspaceID: workspace.id))
        }
        XCTAssertTrue(savedItems.isEmpty)
    }

    func testSaveUsesChosenWorkspaceAndUpdatesWorkspaceTimestamp() async throws {
        let store = MockWorkspaceStore()
        var workspaceA = try store.createWorkspace(title: "Workspace A", description: nil)
        var workspaceB = try store.createWorkspace(title: "Workspace B", description: nil)
        workspaceA.updatedAt = Date(timeIntervalSince1970: 10)
        workspaceB.updatedAt = Date(timeIntervalSince1970: 20)
        try store.saveWorkspace(workspaceA)
        try store.saveWorkspace(workspaceB)

        let api = MockAPIClient()
        api.searchResults = [makeResult(id: "one", title: "One", url: "https://example.com/one")]

        let viewModel = SearchViewModel(
            apiClient: api,
            store: store,
            privacySettingsStore: makePrivacyStore(),
            userDefaults: makeSessionDefaults(),
            preferredWorkspaceStorageKey: "preferredWorkspace"
        )
        viewModel.selectWorkspace(workspaceB)
        viewModel.query = "privacy"
        await viewModel.search()
        viewModel.toggleSelection(for: "one")

        viewModel.saveSelectedResults()

        XCTAssertEqual(try store.fetchItems(workspaceID: workspaceA.id).count, 0)
        XCTAssertEqual(try store.fetchItems(workspaceID: workspaceB.id).count, 1)
        let updatedWorkspaceB = try XCTUnwrap(store.fetchWorkspace(id: workspaceB.id))
        XCTAssertGreaterThan(updatedWorkspaceB.updatedAt, Date(timeIntervalSince1970: 20))
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

        let viewModel = SearchViewModel(
            apiClient: api,
            store: store,
            privacySettingsStore: makePrivacyStore(),
            userDefaults: makeSessionDefaults(),
            preferredWorkspaceStorageKey: "preferredWorkspace"
        )
        XCTAssertTrue(viewModel.createWorkspace(title: "Research Library"))
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

        let viewModel = SearchViewModel(
            apiClient: api,
            store: store,
            privacySettingsStore: makePrivacyStore(),
            userDefaults: makeSessionDefaults(),
            preferredWorkspaceStorageKey: "preferredWorkspace"
        )
        await viewModel.signIn(appleSubject: "dev-user")
        viewModel.query = "privacy"

        await viewModel.search()

        XCTAssertFalse(viewModel.isAuthenticated)
        XCTAssertEqual(api.clearSessionCalls, 1)
        XCTAssertEqual(viewModel.banner?.title, "Sign in again")
    }

    func testCompareRequiresExplicitSaveWhenPrivacySettingDisablesAutoSave() async throws {
        let store = MockWorkspaceStore()
        let api = MockAPIClient()
        api.searchResults = [
            makeResult(id: "one", title: "One", url: "https://example.com/one"),
            makeResult(id: "two", title: "Two", url: "https://example.com/two"),
        ]

        let privacyStore = makePrivacyStore()
        privacyStore.updateAutoSaveSourcesForDeeperModes(false)

        let viewModel = SearchViewModel(
            apiClient: api,
            store: store,
            privacySettingsStore: privacyStore,
            userDefaults: makeSessionDefaults(),
            preferredWorkspaceStorageKey: "preferredWorkspace"
        )
        XCTAssertTrue(viewModel.createWorkspace(title: "Research Library"))
        viewModel.query = "privacy"
        await viewModel.search()
        viewModel.toggleSelection(for: "one")
        viewModel.toggleSelection(for: "two")

        await viewModel.runCompare()

        XCTAssertTrue(api.compareRequests.isEmpty)
        XCTAssertEqual(viewModel.banner?.title, "Save sources first")
    }

    func testCompareUsesRetrievedContentWithoutPersistingWhenPrivacySettingDisablesLocalExtractSave() async throws {
        let store = MockWorkspaceStore()
        let api = MockAPIClient()
        api.searchResults = [
            makeResult(id: "one", title: "One", url: "https://example.com/one"),
            makeResult(id: "two", title: "Two", url: "https://example.com/two"),
        ]
        api.retrievalResponses = [
            "https://example.com/one": StructuredRetrievalDTO(
                url: "https://example.com/one",
                canonical_url: "https://example.com/one",
                title: "Reader One",
                domain: "example.com",
                excerpt: "Readable excerpt one",
                bullet_points: ["Point one"],
                retrieved_at: Date()
            ),
            "https://example.com/two": StructuredRetrievalDTO(
                url: "https://example.com/two",
                canonical_url: "https://example.com/two",
                title: "Reader Two",
                domain: "example.com",
                excerpt: "Readable excerpt two",
                bullet_points: ["Point two"],
                retrieved_at: Date()
            ),
        ]

        let privacyStore = makePrivacyStore()
        privacyStore.updateUseBackendReaderForDeeperModes(true)
        privacyStore.updateSaveRetrievedContentLocally(false)

        let viewModel = SearchViewModel(
            apiClient: api,
            store: store,
            privacySettingsStore: privacyStore,
            userDefaults: makeSessionDefaults(),
            preferredWorkspaceStorageKey: "preferredWorkspace"
        )
        viewModel.query = "privacy"
        await viewModel.search()
        viewModel.toggleSelection(for: "one")
        viewModel.toggleSelection(for: "two")

        await viewModel.runCompare()

        let compareItems = try XCTUnwrap(api.compareRequests.first?.1)
        XCTAssertEqual(compareItems.count, 2)
        XCTAssertEqual(compareItems[0].cleanedExcerpt, "Readable excerpt one")
        XCTAssertEqual(compareItems[1].cleanedExcerpt, "Readable excerpt two")

        let workspace = try XCTUnwrap(store.fetchWorkspaces().first)
        let savedItems = try store.fetchItems(workspaceID: workspace.id)
        XCTAssertEqual(savedItems.count, 2)
        XCTAssertNil(savedItems[0].cleanedExcerpt)
        XCTAssertNil(savedItems[1].cleanedExcerpt)
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

    private func makePrivacyStore() -> PrivacySettingsStore {
        let suiteName = "amon.tests.privacy.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return PrivacySettingsStore(userDefaults: defaults, storageKey: "privacy")
    }

    private func makeSessionDefaults() -> UserDefaults {
        let suiteName = "amon.tests.session.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
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
    var compareRequests: [(String, [Item])] = []
    var researchRequests: [(String, String?, [Item])] = []
    var retrievalResponses: [String: StructuredRetrievalDTO] = [:]
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
        retrievalResponses[url] ?? StructuredRetrievalDTO(
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
        compareRequests.append((title, items))
        return compareResponse
    }

    func research(title: String, promptContext: String?, items: [Item]) async throws -> ResearchResponseDTO {
        researchRequests.append((title, promptContext, items))
        return researchResponse
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

    func resetLocalData() throws {
        workspaces = []
        items = []
        notes = []
        compareArtifacts = []
        researchArtifacts = []
        exportRecords = []
    }
}
