import SwiftUI

public struct WorkspaceDetailView: View {
    public let workspace: Workspace
    public let items: [Item]

    public init(workspace: Workspace, items: [Item]) {
        self.workspace = workspace
        self.items = items
    }

    public var body: some View {
        List(items) { item in
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title).font(.headline)
                Text(item.domain).font(.caption).foregroundStyle(.secondary)
                if let snippet = item.snippet {
                    Text(snippet).font(.subheadline)
                }
            }
        }
        .navigationTitle(workspace.title)
    }
}
