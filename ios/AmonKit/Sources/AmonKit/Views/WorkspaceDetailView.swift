import SwiftUI

public struct WorkspaceDetailView: View {
    @ObservedObject private var viewModel: WorkspaceDetailViewModel

    init(viewModel: WorkspaceDetailViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        List {
            if let banner = viewModel.banner {
                Section {
                    AmonBannerView(banner: banner, dismiss: viewModel.dismissBanner)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
            }

            if let workspace = viewModel.workspace {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(workspace.title)
                            .font(.title3.weight(.semibold))
                        Text("Updated \(AmonFormatters.relativeTimestamp(for: workspace.updatedAt))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            AmonMetadataPill(text: "\(viewModel.items.count) items")
                            AmonMetadataPill(text: "\(viewModel.compareArtifacts.count) compares")
                            AmonMetadataPill(text: "\(viewModel.researchArtifacts.count) research")
                        }
                    }
                    .amonCardStyle(padding: 18)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                }
            }

            if viewModel.items.isEmpty && viewModel.compareArtifacts.isEmpty && viewModel.researchArtifacts.isEmpty {
                Section {
                    AmonEmptyStateView(
                        title: "Nothing saved here yet",
                        message: "Start in Search, save a few sources, then come back here to compare or synthesize them.",
                        systemImage: "tray"
                    )
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                }
            } else {
                if !viewModel.items.isEmpty {
                    Section("Saved Sources") {
                        ForEach(viewModel.items) { item in
                            NavigationLink {
                                if let url = URL(string: item.canonicalURL) {
                                    WebViewContainer(url: url)
                                        .ignoresSafeArea()
                                        .navigationTitle(item.displayTitle)
                                        .navigationBarTitleDisplayMode(.inline)
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(item.displayTitle)
                                        .font(.headline)
                                    Text(item.domain)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if let previewText = item.previewText {
                                        Text(previewText)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(3)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }

                if !viewModel.compareArtifacts.isEmpty {
                    Section("Compare") {
                        ForEach(viewModel.compareArtifacts) { artifact in
                            NavigationLink {
                                ComparePreviewView(artifact: artifact, items: viewModel.items)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(artifact.title)
                                        .font(.headline)
                                    Text(artifact.summary ?? "Structured comparison")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                    Text("Updated \(AmonFormatters.relativeTimestamp(for: artifact.updatedAt))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }

                if !viewModel.researchArtifacts.isEmpty {
                    Section("Research") {
                        ForEach(viewModel.researchArtifacts) { artifact in
                            NavigationLink {
                                ResearchPreviewView(
                                    artifact: artifact,
                                    items: viewModel.items.filter { artifact.itemIDs.contains($0.id) }
                                )
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(artifact.title)
                                        .font(.headline)
                                    Text(artifact.summaryText)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                    Text("Updated \(AmonFormatters.relativeTimestamp(for: artifact.updatedAt))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(viewModel.workspace?.title ?? "Workspace")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            viewModel.refresh()
        }
        .onAppear {
            viewModel.refresh()
        }
    }
}
