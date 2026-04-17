import SwiftUI
import UIKit

public struct WorkspaceDetailView: View {
    @ObservedObject private var viewModel: WorkspaceDetailViewModel
    @ObservedObject private var privacySettingsStore: PrivacySettingsStore
    @StateObject private var browseOpenOrchestrator: BrowseOpenOrchestrator
    @State private var presentedSavedPage: PresentedSavedPage?
    private let apiClient: any AmonAPIClienting

    init(
        viewModel: WorkspaceDetailViewModel,
        apiClient: any AmonAPIClienting,
        privacySettingsStore: PrivacySettingsStore
    ) {
        self.viewModel = viewModel
        self.apiClient = apiClient
        self.privacySettingsStore = privacySettingsStore
        _browseOpenOrchestrator = StateObject(wrappedValue: BrowseOpenOrchestrator(apiClient: apiClient))
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

                        if !viewModel.items.isEmpty {
                            AmonTrustStripView(items: viewModel.ownershipStripItems)
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
                            Button {
                                if let localSnapshot = item.localReaderSnapshot,
                                   let url = URL(string: item.canonicalURL) {
                                    presentedSavedPage = PresentedSavedPage(
                                        title: item.displayTitle,
                                        url: url,
                                        page: localSnapshot
                                    )
                                } else if let url = URL(string: item.canonicalURL) {
                                    Task {
                                        await browseOpenOrchestrator.presentChoices(
                                            for: BrowseOpenTarget(title: item.displayTitle, url: url)
                                        )
                                    }
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(alignment: .top, spacing: 12) {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(item.displayTitle)
                                                .font(.headline)
                                            HStack(spacing: 8) {
                                                Text(item.domain)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                AmonMetadataPill(text: item.ownershipBadgeText)
                                            }
                                            if let previewText = item.previewText {
                                                Text(previewText)
                                                    .font(.subheadline)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(3)
                                            } else {
                                                Text(item.ownershipSummary)
                                                    .font(.subheadline)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(2)
                                            }

                                            if let transitionText = item.ownershipTransitionText {
                                                Text(transitionText)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(2)
                                            }

                                            if viewModel.isPromotingItem(item.id) {
                                                HStack(spacing: 8) {
                                                    ProgressView()
                                                        .controlSize(.small)
                                                    Text("Saving readable copy locally…")
                                                        .font(.caption.weight(.medium))
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                        }

                                        Spacer(minLength: 12)

                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.tertiary)
                                            .padding(.top, 4)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                if item.canPromoteToOwnedReadableCopy {
                                    Button {
                                        Task {
                                            await viewModel.promoteItemToOwnedReadableCopy(item, apiClient: apiClient)
                                        }
                                    } label: {
                                        Label("Save Readable Copy", systemImage: "square.and.arrow.down.on.square")
                                    }
                                }

                                if let localSnapshot = item.localReaderSnapshot,
                                   let url = URL(string: item.canonicalURL) {
                                    Button {
                                        presentedSavedPage = PresentedSavedPage(
                                            title: item.displayTitle,
                                            url: url,
                                            page: localSnapshot
                                        )
                                    } label: {
                                        Label("Open Saved Copy", systemImage: "internaldrive")
                                    }
                                }

                                if let url = URL(string: item.canonicalURL) {
                                    Button {
                                        Task {
                                            await browseOpenOrchestrator.presentChoices(
                                                for: BrowseOpenTarget(title: item.displayTitle, url: url)
                                            )
                                        }
                                    } label: {
                                        Label(
                                            item.hasOwnedReadableContent ? "Open Source..." : "Choose How to Open",
                                            systemImage: "arrow.up.right.square"
                                        )
                                    }

                                    Button {
                                        browseOpenOrchestrator.open(
                                            .standard,
                                            for: BrowseOpenTarget(title: item.displayTitle, url: url)
                                        )
                                    } label: {
                                        Label("Open Normally", systemImage: "arrow.up.right.square")
                                    }

                                    Button {
                                        browseOpenOrchestrator.open(
                                            .cleanView,
                                            for: BrowseOpenTarget(title: item.displayTitle, url: url)
                                        )
                                    } label: {
                                        Label("Clean View", systemImage: "doc.text")
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
                                    metadata: [item.ownershipBadgeText]
                                )
                            }
                        }
                    }
                }

                if !viewModel.compareArtifacts.isEmpty {
                    Section("Compare") {
                        ForEach(viewModel.compareArtifacts) { artifact in
                            let ownership = viewModel.ownedArtifactSummary(for: artifact)
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
                                    HStack(spacing: 8) {
                                        AmonMetadataPill(text: ownership.ownershipBadgeText)
                                        AmonMetadataPill(text: ownership.sourceCoverageBadgeText)
                                    }
                                    if let transitionSummary = ownership.transitionSummary {
                                        Text(transitionSummary)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                    if viewModel.isStrengtheningArtifact(artifact.id) {
                                        HStack(spacing: 8) {
                                            ProgressView()
                                                .controlSize(.small)
                                            Text("Strengthening linked sources…")
                                                .font(.caption.weight(.medium))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Text("Updated \(AmonFormatters.relativeTimestamp(for: artifact.updatedAt))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                            .contextMenu {
                                if ownership.sourceCoverage.needsSourcePromotion {
                                    Button {
                                        Task {
                                            await viewModel.strengthenLinkedSources(for: artifact, apiClient: apiClient)
                                        }
                                    } label: {
                                        Label("Strengthen Linked Sources", systemImage: "square.and.arrow.down.on.square")
                                    }
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if ownership.sourceCoverage.needsSourcePromotion {
                                    Button {
                                        Task {
                                            await viewModel.strengthenLinkedSources(for: artifact, apiClient: apiClient)
                                        }
                                    } label: {
                                        Label("Strengthen", systemImage: "square.and.arrow.down.on.square")
                                    }
                                    .tint(.accentColor)
                                }
                            }
                        }
                    }
                }

                if !viewModel.researchArtifacts.isEmpty {
                    Section("Research") {
                        ForEach(viewModel.researchArtifacts) { artifact in
                            let ownership = viewModel.ownedArtifactSummary(for: artifact)
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
                                    HStack(spacing: 8) {
                                        AmonMetadataPill(text: ownership.ownershipBadgeText)
                                        AmonMetadataPill(text: ownership.sourceCoverageBadgeText)
                                    }
                                    if let transitionSummary = ownership.transitionSummary {
                                        Text(transitionSummary)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                    if viewModel.isStrengtheningArtifact(artifact.id) {
                                        HStack(spacing: 8) {
                                            ProgressView()
                                                .controlSize(.small)
                                            Text("Strengthening linked sources…")
                                                .font(.caption.weight(.medium))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Text("Updated \(AmonFormatters.relativeTimestamp(for: artifact.updatedAt))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                            .contextMenu {
                                if ownership.sourceCoverage.needsSourcePromotion {
                                    Button {
                                        Task {
                                            await viewModel.strengthenLinkedSources(for: artifact, apiClient: apiClient)
                                        }
                                    } label: {
                                        Label("Strengthen Linked Sources", systemImage: "square.and.arrow.down.on.square")
                                    }
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if ownership.sourceCoverage.needsSourcePromotion {
                                    Button {
                                        Task {
                                            await viewModel.strengthenLinkedSources(for: artifact, apiClient: apiClient)
                                        }
                                    } label: {
                                        Label("Strengthen", systemImage: "square.and.arrow.down.on.square")
                                    }
                                    .tint(.accentColor)
                                }
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
        .navigationDestination(item: $presentedSavedPage) { page in
            ReaderPageView(
                title: page.title,
                url: page.url,
                apiClient: apiClient,
                sessionPersistence: privacySettingsStore.settings.browsing.sessionPersistence,
                initialPage: page.page
            )
        }
        .navigationDestination(
            item: Binding(
                get: { browseOpenOrchestrator.presentedPage },
                set: { page in
                    if page == nil {
                        browseOpenOrchestrator.dismissPresentedPage()
                    }
                }
            )
        ) { page in
            PrivacyAwarePageView(
                title: page.title,
                url: page.url,
                apiClient: apiClient,
                privacySettingsStore: privacySettingsStore,
                requestedMode: page.requestedMode
            )
        }
        .confirmationDialog(
            browseOpenOrchestrator.activeChoice?.dialogTitle ?? "Open",
            isPresented: Binding(
                get: { browseOpenOrchestrator.activeChoice != nil },
                set: { isPresented in
                    if !isPresented {
                        browseOpenOrchestrator.dismissChoice()
                    }
                }
            ),
            titleVisibility: .visible,
            presenting: browseOpenOrchestrator.activeChoice
        ) { recommendation in
            Button("Open Normally") {
                browseOpenOrchestrator.open(.standard, from: recommendation)
            }

            Button("Clean View") {
                browseOpenOrchestrator.open(.cleanView, from: recommendation)
            }

            if recommendation.showsProtectedSession {
                Button(recommendation.protectedSessionTitle) {
                    browseOpenOrchestrator.open(.protectedSession, from: recommendation)
                }
            }
        } message: { recommendation in
            if let message = recommendation.message {
                Text(message)
            }
        }
        .refreshable {
            viewModel.refresh()
        }
        .onAppear {
            viewModel.refresh()
        }
    }
}

private struct PresentedSavedPage: Identifiable, Hashable {
    let title: String
    let url: URL
    let page: StructuredRetrievalDTO

    var id: String {
        "\(url.absoluteString)-saved-copy"
    }

    static func == (lhs: PresentedSavedPage, rhs: PresentedSavedPage) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
