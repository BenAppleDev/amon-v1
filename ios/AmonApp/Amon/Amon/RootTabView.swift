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
    @StateObject private var transportSettingsStore: TransportPrivacySettingsStore
    @StateObject private var tunnelManager: TunnelManager
    @State private var selectedTab: AppTab = .search
    @State private var isPresentingSettings = false
    @State private var hasCompletedInitialSessionRestore = false
    @State private var pendingTunnelPrompt: TunnelPromptContext?
    private let apiClient: AmonAPIClient

    init() {
        AmonTheme.applyGlobalAppearance()
        let baseURL = URL(string: "https://api.getamon.com")!
        let apiClient = AmonAPIClient(baseURL: baseURL)
        let privacySettingsStore = PrivacySettingsStore()
        let transportSettingsStore = TransportPrivacySettingsStore()

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
        _transportSettingsStore = StateObject(wrappedValue: transportSettingsStore)
        _tunnelManager = StateObject(wrappedValue: TunnelManager())
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
                        openAppMenu: { isPresentingSettings = true },
                        localRouteStateProvider: {
                            LocalPrivacyRouteState(tunnelStatus: tunnelManager.statusSnapshot.state)
                        }
                    )
                    .tag(AppTab.search)

                    WorkspaceListView(
                        viewModel: workspaceViewModel,
                        apiClient: apiClient,
                        privacySettingsStore: privacySettingsStore,
                        openAppMenu: { isPresentingSettings = true },
                        localRouteStateProvider: {
                            LocalPrivacyRouteState(tunnelStatus: tunnelManager.statusSnapshot.state)
                        }
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
            tunnelManager.recordExternalEvent("RootTabView startup task began")
            await tunnelManager.refreshFromPreferences(using: transportSettingsStore.settings)
            tunnelManager.recordExternalEvent("Tunnel preferences refresh completed during startup")
            await searchViewModel.restoreSessionIfNeeded()
            tunnelManager.recordExternalEvent("Session restore finished; authenticated=\(searchViewModel.isAuthenticated)")
            await BrowserPrivacyController.clearWebsiteDataIfNeededOnLaunch(using: privacySettingsStore.settings)
            hasCompletedInitialSessionRestore = true
            if searchViewModel.isAuthenticated {
                tunnelManager.recordExternalEvent("Handling authenticated state after session restore")
                await handleAuthenticatedState(isSessionRestore: true)
            }
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
        .onChange(of: transportSettingsStore.settings) { _, newValue in
            Task {
                tunnelManager.recordExternalEvent("Transport settings changed to host=\(newValue.endpoint.serverHost.isEmpty ? "<empty>" : newValue.endpoint.serverHost) port=\(newValue.endpoint.serverPort) enabledWhenSignedIn=\(newValue.enabledWhenSignedIn) autoConnectOnRestore=\(newValue.autoConnectOnSessionRestore)")
                await tunnelManager.refreshFromPreferences(using: newValue)
            }
        }
        .onChange(of: searchViewModel.isAuthenticated) { oldValue, newValue in
            guard hasCompletedInitialSessionRestore else { return }
            tunnelManager.recordExternalEvent("Authentication state changed from \(oldValue) to \(newValue)")
            if !oldValue && newValue {
                Task {
                    tunnelManager.recordExternalEvent("Handling authenticated state after fresh sign-in")
                    await handleAuthenticatedState(isSessionRestore: false)
                }
            } else if oldValue && !newValue {
                pendingTunnelPrompt = nil
                tunnelManager.recordExternalEvent("User signed out; disconnecting tunnel")
                tunnelManager.disconnect()
            }
        }
        .sheet(isPresented: $isPresentingSettings) {
            AmonSettingsView(
                searchViewModel: searchViewModel,
                privacySettingsStore: privacySettingsStore,
                transportSettingsStore: transportSettingsStore,
                tunnelStatus: tunnelManager.statusSnapshot,
                tunnelDiagnostics: tunnelManager.diagnostics,
                connectTunnel: {
                    Task {
                        tunnelManager.recordExternalEvent("Manual connect requested from settings")
                        await tunnelManager.connect(using: transportSettingsStore.settings)
                    }
                },
                disconnectTunnel: {
                    tunnelManager.recordExternalEvent("Manual disconnect requested from settings")
                    tunnelManager.disconnect()
                }
            )
        }
        .alert(item: $pendingTunnelPrompt) { prompt in
            Alert(
                title: Text(prompt.title),
                message: Text(prompt.message),
                primaryButton: .default(Text("Connect")) {
                    transportSettingsStore.updateEnabledWhenSignedIn(true)
                    Task {
                        tunnelManager.recordExternalEvent("Tunnel prompt accepted for \(prompt.rawValue)")
                        await tunnelManager.connect(using: transportSettingsStore.settings)
                    }
                },
                secondaryButton: .cancel(Text("Not now")) {
                    tunnelManager.recordExternalEvent("Tunnel prompt dismissed for \(prompt.rawValue)")
                }
            )
        }
    }

    private func handleAuthenticatedState(isSessionRestore: Bool) async {
        let settings = transportSettingsStore.settings
        tunnelManager.recordExternalEvent("Refreshing tunnel state for authenticated session; restore=\(isSessionRestore)")
        await tunnelManager.refreshFromPreferences(using: settings)

        guard settings.endpoint.isConfigured else {
            tunnelManager.recordExternalEvent("Authenticated state handling skipped because endpoint is not configured")
            return
        }

        if settings.enabledWhenSignedIn {
            if isSessionRestore && !settings.autoConnectOnSessionRestore {
                if tunnelManager.statusSnapshot.state == .disconnected {
                    tunnelManager.recordExternalEvent("Session restored with auto-connect disabled; prompting for reconnect")
                    pendingTunnelPrompt = .sessionRestore
                }
                return
            }

            tunnelManager.recordExternalEvent("Auto-connect path chosen; requesting tunnel connect")
            await tunnelManager.connect(using: settings)
        } else if tunnelManager.statusSnapshot.state == .disconnected {
            tunnelManager.recordExternalEvent("Tunnel not enabled when signed in; presenting opt-in prompt")
            pendingTunnelPrompt = isSessionRestore ? .sessionRestore : .signIn
        }
    }
}

private enum TunnelPromptContext: String, Identifiable {
    case signIn
    case sessionRestore

    var id: String { rawValue }

    var title: String {
        switch self {
        case .signIn:
            return "Connect Amon tunnel?"
        case .sessionRestore:
            return "Reconnect the Amon tunnel?"
        }
    }

    var message: String {
        switch self {
        case .signIn:
            return "Amon can route browsing traffic through your laptop endpoint while you're signed in."
        case .sessionRestore:
            return "Your session came back. Amon can reconnect the development tunnel for this device."
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
