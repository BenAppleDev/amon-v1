import Foundation

@MainActor
final class WorkspaceDetailViewModel: ObservableObject {
    @Published private(set) var workspace: Workspace?
    @Published private(set) var items: [Item] = []
    @Published private(set) var compareArtifacts: [CompareArtifact] = []
    @Published private(set) var researchArtifacts: [ResearchArtifact] = []
    @Published private(set) var isLoading: Bool = false
    @Published var banner: AmonBanner?

    private let store: WorkspaceStore
    private let workspaceID: String

    init(store: WorkspaceStore, workspaceID: String) {
        self.store = store
        self.workspaceID = workspaceID
        refresh()
    }

    func refresh() {
        isLoading = true
        defer { isLoading = false }

        do {
            workspace = try store.fetchWorkspace(id: workspaceID)
            items = try store.fetchItems(workspaceID: workspaceID)
                .filter { !$0.isDeleted }
                .sorted(by: { $0.updatedAt > $1.updatedAt })
            compareArtifacts = try store.fetchCompareArtifacts(workspaceID: workspaceID)
                .sorted(by: { $0.updatedAt > $1.updatedAt })
            researchArtifacts = try store.fetchResearchArtifacts(workspaceID: workspaceID)
                .sorted(by: { $0.updatedAt > $1.updatedAt })
        } catch {
            banner = AmonBanner(
                tone: .error,
                title: "Couldn't load this workspace",
                message: AmonErrorPresenter.message(for: error, fallback: "Amon couldn't load that workspace.")
            )
        }
    }

    func dismissBanner() {
        banner = nil
    }
}
