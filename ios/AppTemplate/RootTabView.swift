import AmonKit
import SwiftUI

struct RootTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var searchViewModel: SearchViewModel
    @StateObject private var workspaceViewModel: WorkspaceListViewModel
    @StateObject private var privacySettingsStore: PrivacySettingsStore
    private let apiClient: AmonAPIClient

    init() {
        let baseURL = URL(string: "http://127.0.0.1:8000")!
        let apiClient = AmonAPIClient(baseURL: baseURL)
        let privacySettingsStore = PrivacySettingsStore()
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dbURL = documents.appendingPathComponent("amon-local.sqlite")
        let store = try! SQLiteWorkspaceStore(databaseURL: dbURL)
        let workspaceViewModel = WorkspaceListViewModel(store: store)
        let searchViewModel = SearchViewModel(
            apiClient: apiClient,
            store: store,
            privacySettingsStore: privacySettingsStore
        )
        searchViewModel.setWorkspaceDidChangeHandler {
            workspaceViewModel.refresh()
        }
        self.apiClient = apiClient
        _searchViewModel = StateObject(wrappedValue: searchViewModel)
        _workspaceViewModel = StateObject(wrappedValue: workspaceViewModel)
        _privacySettingsStore = StateObject(wrappedValue: privacySettingsStore)
    }

    var body: some View {
        Group {
            if searchViewModel.isRestoringSession {
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(.circular)
                    Text("Checking your local session")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if searchViewModel.isAuthenticated {
                TabView {
                    SearchView(
                        viewModel: searchViewModel,
                        privacySettingsStore: privacySettingsStore
                    )
                        .tabItem {
                            Label("Search", systemImage: "magnifyingglass")
                        }

                    WorkspaceListView(
                        viewModel: workspaceViewModel,
                        apiClient: apiClient,
                        privacySettingsStore: privacySettingsStore
                    )
                        .tabItem {
                            Label("Workspace", systemImage: "folder")
                        }
                }
            } else {
                SignInView(viewModel: searchViewModel)
            }
        }
        .tint(Color(uiColor: .systemTeal))
        .task {
            await searchViewModel.restoreSessionIfNeeded()
            await BrowserPrivacyController.clearWebsiteDataIfNeededOnLaunch(using: privacySettingsStore.settings)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                Task {
                    await BrowserPrivacyController.clearWebsiteDataIfNeededOnBackground(using: privacySettingsStore.settings)
                }
            }
        }
        .onChange(of: privacySettingsStore.settings.browsing.sessionPersistence) { oldValue, newValue in
            if oldValue != newValue && newValue != .persistent {
                Task {
                    await BrowserPrivacyController.clearWebsiteData()
                }
            }
        }
    }
}
