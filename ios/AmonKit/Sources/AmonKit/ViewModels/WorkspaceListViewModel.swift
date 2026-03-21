import Foundation

struct WorkspaceSummary: Identifiable, Equatable {
    let workspace: Workspace
    let itemCount: Int
    let compareCount: Int
    let researchCount: Int

    var id: String { workspace.id }
    var title: String { workspace.title }
    var updatedAt: Date { workspace.updatedAt }
}

@MainActor
public final class WorkspaceListViewModel: ObservableObject {
    @Published private(set) var workspaceSummaries: [WorkspaceSummary] = []
    @Published private(set) var isLoading: Bool = false
    @Published var banner: AmonBanner?

    let store: WorkspaceStore

    public init(store: WorkspaceStore) {
        self.store = store
        refresh()
    }

    public func refresh() {
        isLoading = true
        defer { isLoading = false }

        do {
            let workspaces = try store.fetchWorkspaces()
            workspaceSummaries = try workspaces.map { workspace in
                let items = try store.fetchItems(workspaceID: workspace.id).filter { !$0.isDeleted }
                let compareArtifacts = try store.fetchCompareArtifacts(workspaceID: workspace.id)
                let researchArtifacts = try store.fetchResearchArtifacts(workspaceID: workspace.id)
                return WorkspaceSummary(
                    workspace: workspace,
                    itemCount: items.count,
                    compareCount: compareArtifacts.count,
                    researchCount: researchArtifacts.count
                )
            }
            .sorted(by: { $0.updatedAt > $1.updatedAt })
        } catch {
            banner = AmonBanner(
                tone: .error,
                title: "Couldn't load workspace",
                message: AmonErrorPresenter.message(for: error, fallback: "Amon couldn't load your saved work.")
            )
        }
    }

    @discardableResult
    func createWorkspace(title: String, description: String?) -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            banner = AmonBanner(
                tone: .info,
                title: "Add a name",
                message: "Give the workspace a clear title so it feels like a place you own."
            )
            return false
        }

        do {
            _ = try store.createWorkspace(title: trimmedTitle, description: description)
            refresh()
            banner = AmonBanner(
                tone: .success,
                title: "Workspace created",
                message: "Saved locally and ready for new research."
            )
            return true
        } catch {
            banner = AmonBanner(
                tone: .error,
                title: "Couldn't create workspace",
                message: AmonErrorPresenter.message(for: error, fallback: "Amon couldn't create that workspace.")
            )
            return false
        }
    }

    func dismissBanner() {
        banner = nil
    }

    func suggestedWorkspaceTitle() -> String {
        workspaceSummaries.isEmpty ? "Research Library" : "Workspace \(workspaceSummaries.count + 1)"
    }

    func makeDetailViewModel(for summary: WorkspaceSummary) -> WorkspaceDetailViewModel {
        WorkspaceDetailViewModel(store: store, workspaceID: summary.id)
    }
}
