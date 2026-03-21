import SwiftUI

public struct WorkspaceListView: View {
    @ObservedObject private var viewModel: WorkspaceListViewModel

    public init(viewModel: WorkspaceListViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            List(viewModel.workspaces) { workspace in
                NavigationLink(workspace.title) {
                    WorkspaceDetailView(workspace: workspace, items: viewModel.items(for: workspace))
                }
            }
            .navigationTitle("Workspace")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New") {
                        viewModel.createWorkspace(title: "Workspace \(viewModel.workspaces.count + 1)", description: nil)
                    }
                }
            }
        }
    }
}
