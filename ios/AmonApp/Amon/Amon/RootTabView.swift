import AmonKit
import SwiftUI

struct RootTabView: View {
    @StateObject private var searchViewModel: SearchViewModel
    @StateObject private var workspaceViewModel: WorkspaceListViewModel

    init() {
        let baseURL = URL(string: "http://10.220.233.167:8000")!
        let apiClient = AmonAPIClient(baseURL: baseURL)

        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dbURL = documents.appendingPathComponent("amon-local.sqlite")
        let store = try! SQLiteWorkspaceStore(databaseURL: dbURL)

        _searchViewModel = StateObject(
            wrappedValue: SearchViewModel(apiClient: apiClient, store: store)
        )
        _workspaceViewModel = StateObject(
            wrappedValue: WorkspaceListViewModel(store: store)
        )
    }

    var body: some View {
        Group {
            if searchViewModel.isAuthenticated {
                TabView {
                    SearchView(viewModel: searchViewModel)
                        .tabItem {
                            Label("Search", systemImage: "magnifyingglass")
                        }

                    WorkspaceListView(viewModel: workspaceViewModel)
                        .tabItem {
                            Label("Workspace", systemImage: "folder")
                        }
                }
            } else {
                SignInView(viewModel: searchViewModel)
            }
        }
    }
}
