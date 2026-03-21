import Foundation

@MainActor
public final class WorkspaceListViewModel: ObservableObject {
    @Published public var workspaces: [Workspace] = []
    @Published public var errorMessage: String?

    private let store: WorkspaceStore

    public init(store: WorkspaceStore) {
        self.store = store
        refresh()
    }

    public func refresh() {
        do {
            workspaces = try store.fetchWorkspaces()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func createWorkspace(title: String, description: String?) {
        do {
            _ = try store.createWorkspace(title: title, description: description)
            refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func items(for workspace: Workspace) -> [Item] {
        (try? store.fetchItems(workspaceID: workspace.id)) ?? []
    }
}
