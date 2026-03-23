import SwiftUI
import UIKit

public struct WorkspaceDetailView: View {
    @ObservedObject private var viewModel: WorkspaceDetailViewModel
    @ObservedObject private var privacySettingsStore: PrivacySettingsStore
    private let apiClient: any AmonAPIClienting

    init(
        viewModel: WorkspaceDetailViewModel,
        apiClient: any AmonAPIClienting,
        privacySettingsStore: PrivacySettingsStore
    ) {
        self.viewModel = viewModel
        self.apiClient = apiClient
        self.privacySettingsStore = privacySettingsStore
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

                        HStack(spacing: 8) {
                            AmonMetadataPill(text: "\(viewModel.items.count) items")
                            AmonMetadataPill(text: "\(viewModel.compareArtifacts.count) compares")
                            AmonMetadataPill(text: "\(viewModel.researchArtifacts.count) research")
                        }

                        Text("Updated \(AmonFormatters.relativeTimestamp(for: workspace.updatedAt))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
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
                                    PrivacyAwarePageView(
                                        title: item.displayTitle,
                                        url: url,
                                        apiClient: apiClient,
                                        privacySettingsStore: privacySettingsStore
                                    )
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
                            .contextMenu {
                                if let url = URL(string: item.canonicalURL) {
                                    Button {
                                        UIApplication.shared.open(url)
                                    } label: {
                                        Label("Open", systemImage: "arrow.up.right.square")
                                    }
                                }

                                Button {
                                    UIPasteboard.general.string = item.canonicalURL
                                    AmonHaptics.success()
                                } label: {
                                    Label("Copy Link", systemImage: "link")
                                }
                            } preview: {
                                AmonSourcePreviewCard(
                                    title: item.displayTitle,
                                    domain: item.domain,
                                    summary: item.previewText,
                                    metadata: []
                                )
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
        .background(AmonTheme.canvas)
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
