import SwiftUI

public struct WorkspaceListView: View {
    @ObservedObject private var viewModel: WorkspaceListViewModel
    @State private var isPresentingNewWorkspace = false
    @State private var newWorkspaceTitle = ""

    public init(viewModel: WorkspaceListViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header

                        if let banner = viewModel.banner {
                            AmonBannerView(banner: banner, dismiss: viewModel.dismissBanner)
                        }

                        if viewModel.workspaceSummaries.isEmpty {
                            AmonEmptyStateView(
                                title: "Your local library starts here",
                                message: "Saved searches, compares, and research will accumulate here as durable workspaces you can revisit anytime.",
                                systemImage: "folder.badge.plus",
                                actionTitle: "Create workspace",
                                action: presentCreateWorkspace
                            )
                        } else {
                            LazyVStack(spacing: 14) {
                                ForEach(viewModel.workspaceSummaries) { summary in
                                    NavigationLink {
                                        WorkspaceDetailView(viewModel: viewModel.makeDetailViewModel(for: summary))
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
            .navigationTitle("Workspace")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: presentCreateWorkspace) {
                        Image(systemName: "plus")
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your durable local work")
                .font(.title2.weight(.semibold))
            Text("Workspaces keep sources, compare tables, and research summaries together so the app feels owned rather than historical.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(summary.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Updated \(AmonFormatters.relativeTimestamp(for: summary.updatedAt))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 8) {
                AmonMetadataPill(text: "\(summary.itemCount) items")
                AmonMetadataPill(text: "\(summary.compareCount) compares")
                AmonMetadataPill(text: "\(summary.researchCount) research")
            }
        }
        .amonCardStyle()
    }
}
