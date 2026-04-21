import SwiftUI

public struct WorkspaceListView: View {
    @ObservedObject private var viewModel: WorkspaceListViewModel
    @ObservedObject private var privacySettingsStore: PrivacySettingsStore
    private let apiClient: any AmonAPIClienting
    private let openAppMenu: () -> Void
    private let localRouteStateProvider: () -> LocalPrivacyRouteState
    @State private var isPresentingNewWorkspace = false
    @State private var newWorkspaceTitle = ""

    public init(
        viewModel: WorkspaceListViewModel,
        apiClient: any AmonAPIClienting,
        privacySettingsStore: PrivacySettingsStore,
        openAppMenu: @escaping () -> Void,
        localRouteStateProvider: @escaping () -> LocalPrivacyRouteState = { .unavailable }
    ) {
        self.viewModel = viewModel
        self.apiClient = apiClient
        self.privacySettingsStore = privacySettingsStore
        self.openAppMenu = openAppMenu
        self.localRouteStateProvider = localRouteStateProvider
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AmonTheme.canvas
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if let banner = viewModel.banner {
                            AmonBannerView(banner: banner, dismiss: viewModel.dismissBanner)
                        }

                        if !viewModel.workspaceSummaries.isEmpty {
                            AmonTrustStripView(items: ["Saved locally", "\(viewModel.workspaceSummaries.count) workspaces"])
                        }

                        if viewModel.workspaceSummaries.isEmpty {
                            AmonEmptyStateView(
                                title: "No workspaces yet",
                                message: "Create one when you're ready to keep important sources together.",
                                systemImage: "folder.badge.plus",
                                actionTitle: "Create workspace",
                                action: presentCreateWorkspace
                            )
                        } else {
                            LazyVStack(spacing: 14) {
                                ForEach(viewModel.workspaceSummaries) { summary in
                                    NavigationLink {
                                        WorkspaceDetailView(
                                            viewModel: viewModel.makeDetailViewModel(for: summary),
                                            apiClient: apiClient,
                                            privacySettingsStore: privacySettingsStore,
                                            localRouteStateProvider: localRouteStateProvider
                                        )
                                    } label: {
                                        WorkspaceSummaryCard(summary: summary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 32)
                }
                .refreshable {
                    viewModel.refresh()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: presentCreateWorkspace) {
                        AmonToolbarIconButton(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: openAppMenu) {
                        AmonToolbarIconButton(systemName: "person.crop.circle")
                    }
                }
            }
            .onAppear {
                viewModel.refresh()
            }
            .sheet(isPresented: $isPresentingNewWorkspace) {
                NavigationStack {
                    Form {
                        Section("Title") {
                            TextField("Workspace name", text: $newWorkspaceTitle)
                                .textInputAutocapitalization(.words)
                        }

                        Section {
                            Text("Workspaces are saved locally and hold sources, compares, and research notes together.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .navigationTitle("New Workspace")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Cancel") {
                                isPresentingNewWorkspace = false
                            }
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Create") {
                                if viewModel.createWorkspace(title: newWorkspaceTitle, description: nil) {
                                    isPresentingNewWorkspace = false
                                }
                            }
                            .fontWeight(.semibold)
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }

    private func presentCreateWorkspace() {
        newWorkspaceTitle = viewModel.suggestedWorkspaceTitle()
        isPresentingNewWorkspace = true
    }
}

private struct WorkspaceSummaryCard: View {
    let summary: WorkspaceSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 40, height: 40)

                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(summary.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Updated \(AmonFormatters.relativeTimestamp(for: summary.updatedAt))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            HStack(spacing: 8) {
                AmonMetadataPill(text: "\(summary.itemCount) items")
                AmonMetadataPill(text: "\(summary.compareCount) compares")
                AmonMetadataPill(text: "\(summary.researchCount) research")
            }
        }
        .amonCardStyle()
        .overlay(alignment: .topTrailing) {
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .padding(18)
        }
    }
}
