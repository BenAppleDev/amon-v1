import AmonKit
import SwiftUI

private enum AppTab: Hashable {
    case search
    case workspace
}

struct RootTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var searchViewModel: SearchViewModel
    @StateObject private var workspaceViewModel: WorkspaceListViewModel
    @StateObject private var privacySettingsStore: PrivacySettingsStore
    @State private var selectedTab: AppTab = .search
    @State private var isPresentingSettings = false
    private let apiClient: AmonAPIClient

    init() {
        AmonTheme.applyGlobalAppearance()
        let baseURL = URL(string: "http://10.250.121.117:8000")!
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
                TabView(selection: $selectedTab) {
                    SearchView(
                        viewModel: searchViewModel,
                        privacySettingsStore: privacySettingsStore,
                        openAppMenu: { isPresentingSettings = true }
                    )
                    .tag(AppTab.search)

                    WorkspaceListView(
                        viewModel: workspaceViewModel,
                        apiClient: apiClient,
                        privacySettingsStore: privacySettingsStore,
                        openAppMenu: { isPresentingSettings = true }
                    )
                    .tag(AppTab.workspace)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.snappy(duration: 0.22), value: selectedTab)
                .safeAreaInset(edge: .bottom) {
                    AmonPrimaryTabBar(selectedTab: $selectedTab)
                        .padding(.horizontal, 18)
                        .padding(.top, 8)
                        .padding(.bottom, 10)
                }
            } else {
                SignInView(viewModel: searchViewModel)
            }
        }
        .tint(AmonTheme.accent)
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
        .sheet(isPresented: $isPresentingSettings) {
            AmonSettingsView(
                searchViewModel: searchViewModel,
                privacySettingsStore: privacySettingsStore
            )
        }
    }
}

private struct AmonPrimaryTabBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack(spacing: 10) {
            tabButton(tab: .search, title: "Search", systemImage: "magnifyingglass")
            tabButton(tab: .workspace, title: "Workspace", systemImage: "square.stack.3d.up")
        }
        .padding(8)
        .background(AmonTheme.tabBarSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(AmonTheme.border.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: AmonTheme.shadow, radius: 18, y: 8)
    }

    private func tabButton(tab: AppTab, title: String, systemImage: String) -> some View {
        Button {
            guard selectedTab != tab else { return }
            selectedTab = tab
            AmonHaptics.selection()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(selectedTab == tab ? Color.white : Color.secondary)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(selectedTab == tab ? AmonTheme.accent : Color.clear, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
