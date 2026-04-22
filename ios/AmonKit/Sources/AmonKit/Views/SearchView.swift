import SwiftUI

public struct SearchView: View {
    @ObservedObject private var viewModel: SearchViewModel
    @ObservedObject private var privacySettingsStore: PrivacySettingsStore
    @StateObject private var browseOpenOrchestrator: BrowseOpenOrchestrator
    private let openAppMenu: () -> Void
    @FocusState private var isSearchFieldFocused: Bool
    @State private var isPresentingWorkspaceChooser = false
    @State private var newWorkspaceTitle = ""
    @State private var pendingWorkspaceAction: PendingWorkspaceAction?

    public init(
        viewModel: SearchViewModel,
        privacySettingsStore: PrivacySettingsStore,
        openAppMenu: @escaping () -> Void,
        localRouteCapabilityProvider: @escaping () -> LocalRouteCapabilitySnapshot = { .unsupported }
    ) {
        self.viewModel = viewModel
        self.privacySettingsStore = privacySettingsStore
        self.openAppMenu = openAppMenu
        _browseOpenOrchestrator = StateObject(
            wrappedValue: BrowseOpenOrchestrator(
                apiClient: viewModel.apiClient,
                localRouteCapabilityProvider: localRouteCapabilityProvider
            )
        )
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AmonTheme.canvas
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        searchComposer
                        AmonTrustStripView(items: ["Saved locally", "No server history"])

                        if let banner = viewModel.banner {
                            AmonBannerView(banner: banner, dismiss: viewModel.dismissBanner)
                        }

                        content
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, viewModel.shouldShowSelectionBar ? 120 : 32)
                }
                .scrollDismissesKeyboard(.interactively)
                .contentShape(Rectangle())
                .simultaneousGesture(
                    TapGesture().onEnded {
                        isSearchFieldFocused = false
                    }
                )
            }
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                if viewModel.shouldShowSelectionBar {
                    selectionActionBar
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 10)
                        .background(.ultraThinMaterial)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: openAppMenu) {
                        AmonToolbarIconButton(systemName: "person.crop.circle")
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isSearchFieldFocused = false
                    }
                }
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
                    apiClient: viewModel.apiClient,
                    privacySettingsStore: privacySettingsStore,
                    requestedPath: page.requestedPath,
                    resolvedPath: page.effectivePath,
                    localRouteState: page.localRouteState,
                    localRouteDetail: page.localRouteDetail,
                    fallbackReason: page.fallbackReason
                )
            }
            .sheet(
                item: Binding(
                    get: { browseOpenOrchestrator.activeChoice },
                    set: { choice in
                        if choice == nil {
                            browseOpenOrchestrator.dismissChoice()
                        }
                    }
                )
            ) { recommendation in
                AmonBrowseModeSheet(choice: recommendation) { path in
                    browseOpenOrchestrator.open(path, from: recommendation)
                }
            }
            .sheet(isPresented: $isPresentingWorkspaceChooser, onDismiss: {
                pendingWorkspaceAction = nil
            }) {
                SearchWorkspaceChooserSheet(
                    workspaces: viewModel.availableWorkspaces,
                    selectedWorkspaceID: viewModel.currentWorkspace?.id,
                    newWorkspaceTitle: $newWorkspaceTitle,
                    onSelect: handleWorkspaceSelection(_:),
                    onCreate: createWorkspaceFromSheet
                )
            }
            .sheet(item: $viewModel.activePresentation) { presentation in
                NavigationStack {
                    switch presentation {
                    case .compare(let artifact, let items):
                        ComparePreviewView(artifact: artifact, items: items)
                    case .research(let artifact, let items):
                        ResearchPreviewView(artifact: artifact, items: items)
                    }
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            viewModel.dismissPresentation()
                        }
                    }
                }
            }
        }
    }

    private var searchComposer: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AmonTheme.muted)

                    TextField("Search the web privately", text: $viewModel.query)
                        .font(.body.weight(.medium))
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .submitLabel(.search)
                        .focused($isSearchFieldFocused)
                        .onSubmit {
                            submitSearch()
                        }

                    if !viewModel.query.isEmpty {
                        Button {
                            viewModel.query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(AmonTheme.muted)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear search")
                    }
                }
                .amonInputStyle(cornerRadius: 22, verticalPadding: 16)

                Button(action: submitSearch) {
                    if viewModel.isSearching {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(AmonTheme.canvas)
                    } else {
                        Text("Search")
                    }
                }
                .buttonStyle(AmonPrimaryButtonStyle(minHeight: 56, horizontalPadding: 18))
                .frame(width: 108)
                .disabled(!viewModel.canSubmitSearch)
            }

            workspaceDestinationCard

            if !viewModel.results.isEmpty {
                HStack(spacing: 8) {
                    AmonMetadataPill(text: "\(viewModel.results.count) results")
                    if viewModel.selectedCount > 0 {
                        AmonMetadataPill(text: "\(viewModel.selectedCount) selected")
                    }
                }
            }
        }
    }

    private var workspaceDestinationCard: some View {
        Button {
            presentWorkspaceChooser()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "folder")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(viewModel.currentWorkspace == nil ? AmonTheme.accent : AmonTheme.ink)
                    .frame(width: 34, height: 34)
                    .background(
                        (viewModel.currentWorkspace == nil ? AmonTheme.accent.opacity(0.12) : AmonTheme.pillSurface),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.currentWorkspaceTitle ?? "Choose a workspace")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AmonTheme.ink)

                    Text(viewModel.currentWorkspaceSubtitle)
                        .font(.caption)
                        .foregroundStyle(AmonTheme.muted)
                        .lineLimit(1)
                }

                Spacer(minLength: 12)

                Text(viewModel.workspaceChooserButtonTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AmonTheme.accent)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AmonTheme.muted)
            }
            .amonCardStyle(padding: 13)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isSearching {
                AmonEmptyStateView(
                    title: "Searching",
                    message: "Looking up results from the backend.",
                    systemImage: "magnifyingglass.circle"
                )
        } else if viewModel.results.isEmpty {
            if viewModel.hasSearched {
                AmonEmptyStateView(
                    title: "No results",
                    message: "Try a broader query or a different phrase.",
                    systemImage: "doc.text.magnifyingglass"
                )
            } else {
                AmonEmptyStateView(
                    title: "Search when you're ready",
                    message: "Open, save, compare, or research the sources that matter.",
                    systemImage: "magnifyingglass"
                )
            }
        } else {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.results, id: \.id) { result in
                        SearchResultCard(
                            result: result,
                            isSelected: viewModel.isSelected(result),
                            isSaved: viewModel.isSaved(result),
                            isBusy: viewModel.isSavingLocally || viewModel.isRunningCompare || viewModel.isRunningResearch,
                            isPreparingOpenChoice: browseOpenOrchestrator.isPreparingChoice(for: result.url),
                            onOpenChooser: {
                                guard let url = URL(string: result.url) else { return }
                                Task {
                                    await browseOpenOrchestrator.presentChoices(
                                        for: BrowseOpenTarget(title: result.title, url: url)
                                    )
                                }
                            },
                            onOpenLocalRouted: {
                                guard let url = URL(string: result.url) else { return }
                                browseOpenOrchestrator.open(.localRouted, for: BrowseOpenTarget(title: result.title, url: url))
                            },
                            onOpenCleanView: {
                                guard let url = URL(string: result.url) else { return }
                                browseOpenOrchestrator.open(.cleanView, for: BrowseOpenTarget(title: result.title, url: url))
                            },
                            onOpenDirectFallback: {
                                guard let url = URL(string: result.url) else { return }
                                browseOpenOrchestrator.open(.directFallback, for: BrowseOpenTarget(title: result.title, url: url))
                            },
                            onSave: {
                                AmonHaptics.success()
                                runAction(.saveResult(result.id))
                            },
                        onToggleSelection: {
                            AmonHaptics.selection()
                            viewModel.toggleSelection(for: result.id)
                        },
                        onQuickCompare: {
                            AmonHaptics.softImpact()
                            viewModel.selectResultIfNeeded(result.id)
                            runAction(.compare)
                        },
                        onQuickResearch: {
                            AmonHaptics.softImpact()
                            viewModel.selectResultIfNeeded(result.id)
                            runAction(.research)
                        }
                    )
                }
            }
        }
    }

    private var selectionActionBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(viewModel.selectedCount) selected")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AmonTheme.muted)

            HStack(spacing: 10) {
                Button {
                    runAction(.saveSelection)
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AmonSecondaryButtonStyle())
                .disabled(!viewModel.canSaveSelection)

                Button {
                    AmonHaptics.softImpact()
                    runAction(.compare)
                } label: {
                    Label("Compare", systemImage: "square.split.2x2")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AmonSecondaryButtonStyle())
                .disabled(!viewModel.canCompare)

                Button {
                    AmonHaptics.softImpact()
                    runAction(.research)
                } label: {
                    Label("Research", systemImage: "text.magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AmonPrimaryButtonStyle())
                .disabled(!viewModel.canResearch)
            }
        }
        .padding(16)
        .background(AmonTheme.softCanvas.opacity(0.96), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(AmonTheme.border, lineWidth: 1)
        )
        .shadow(color: AmonTheme.shadow, radius: 18, y: 8)
    }

    private func submitSearch() {
        guard viewModel.canSubmitSearch else { return }
        isSearchFieldFocused = false
        Task { await viewModel.search() }
    }

    private func presentWorkspaceChooser(for action: PendingWorkspaceAction? = nil) {
        pendingWorkspaceAction = action
        newWorkspaceTitle = suggestedWorkspaceTitle
        isPresentingWorkspaceChooser = true
    }

    private func handleWorkspaceSelection(_ workspace: Workspace) {
        viewModel.selectWorkspace(workspace)
        let action = pendingWorkspaceAction
        pendingWorkspaceAction = nil
        isPresentingWorkspaceChooser = false
        if let action {
            DispatchQueue.main.async {
                runResolvedAction(action)
            }
        }
    }

    @discardableResult
    private func createWorkspaceFromSheet() -> Bool {
        guard viewModel.createWorkspace(title: newWorkspaceTitle, description: nil) else {
            return false
        }

        let action = pendingWorkspaceAction
        pendingWorkspaceAction = nil
        isPresentingWorkspaceChooser = false
        if let action {
            DispatchQueue.main.async {
                runResolvedAction(action)
            }
        }
        return true
    }

    private func runAction(_ action: PendingWorkspaceAction) {
        if viewModel.requiresWorkspaceSelectionForSave {
            presentWorkspaceChooser(for: action)
            return
        }
        runResolvedAction(action)
    }

    private func runResolvedAction(_ action: PendingWorkspaceAction) {
        switch action {
        case .saveResult(let resultID):
            guard let result = viewModel.results.first(where: { $0.id == resultID }) else { return }
            viewModel.save(result: result)
        case .saveSelection:
            viewModel.saveSelectedResults()
        case .compare:
            Task { await viewModel.runCompare() }
        case .research:
            Task { await viewModel.runResearch() }
        }
    }

    private var suggestedWorkspaceTitle: String {
        viewModel.availableWorkspaces.isEmpty
            ? "Research Library"
            : "Workspace \(viewModel.availableWorkspaces.count + 1)"
    }

}

private enum PendingWorkspaceAction {
    case saveResult(String)
    case saveSelection
    case compare
    case research
}

private struct SearchResultCard: View {
    let result: SearchResult
    let isSelected: Bool
    let isSaved: Bool
    let isBusy: Bool
    let isPreparingOpenChoice: Bool
    let onOpenChooser: () -> Void
    let onOpenLocalRouted: () -> Void
    let onOpenCleanView: () -> Void
    let onOpenDirectFallback: () -> Void
    let onSave: () -> Void
    let onToggleSelection: () -> Void
    let onQuickCompare: () -> Void
    let onQuickResearch: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(result.title)
                            .font(.headline)
                            .foregroundStyle(AmonTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(result.domain)
                            .font(.subheadline)
                            .foregroundStyle(AmonTheme.muted)
                    }

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AmonTheme.accent)
                            .font(.title3)
                    }
                }

                if !result.metadataPills.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(result.metadataPills, id: \.self) { item in
                                AmonMetadataPill(text: item)
                            }
                        }
                    }
                }

                if let snippet = result.snippet, !snippet.isEmpty {
                    Text(snippet)
                        .font(.subheadline)
                        .foregroundStyle(AmonTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                Button(action: onOpenChooser) {
                    AmonActionChip(
                        title: isPreparingOpenChoice ? "Checking..." : "Open Modes",
                        systemImage: isPreparingOpenChoice ? "ellipsis.circle" : "square.grid.2x2",
                        tone: .accent
                    )
                }
                .buttonStyle(.plain)
                .disabled(isPreparingOpenChoice)

                Button(action: onSave) {
                    AmonActionChip(
                        title: isSaved ? "Saved" : "Save",
                        systemImage: isSaved ? "checkmark.circle.fill" : "square.and.arrow.down",
                        tone: isSaved ? .selected : .neutral
                    )
                }
                .buttonStyle(.plain)
                .disabled(isBusy)

                if isSelected {
                    Button(action: onToggleSelection) {
                        AmonActionChip(
                            title: "Selected",
                            systemImage: "checkmark.circle.fill",
                            tone: .selected
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: onToggleSelection) {
                        AmonActionChip(title: "Select", systemImage: "checkmark.circle")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .amonCardStyle(padding: 16)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(isSelected ? AmonTheme.strongBorder : .clear, lineWidth: 1.5)
        )
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .contextMenu {
            Button(action: onOpenChooser) {
                Label("Open Modes", systemImage: "square.grid.2x2")
            }

            Button(action: onOpenLocalRouted) {
                Label("Open Local (Privacy Route)", systemImage: "arrow.up.right.square")
            }

            Button(action: onOpenCleanView) {
                Label("Clean View", systemImage: "doc.text")
            }

            Button(action: onOpenDirectFallback) {
                Label("Open Direct (Fallback)", systemImage: "arrowshape.turn.up.right")
            }

            Button(action: onSave) {
                Label(isSaved ? "Save Again" : "Save", systemImage: "square.and.arrow.down")
            }
            .disabled(isBusy)

            Button(action: onToggleSelection) {
                Label(isSelected ? "Deselect" : "Select", systemImage: isSelected ? "checkmark.circle.fill" : "checkmark.circle")
            }

            Divider()

            Button(action: onQuickCompare) {
                Label("Compare", systemImage: "square.split.2x2")
            }

            Button(action: onQuickResearch) {
                Label("Research", systemImage: "text.magnifyingglass")
            }
        } preview: {
            AmonSourcePreviewCard(
                title: result.title,
                domain: result.domain,
                summary: result.snippet,
                metadata: result.metadataPills
            )
        }
    }
}

private struct SearchWorkspaceChooserSheet: View {
    @Environment(\.dismiss) private var dismiss
    let workspaces: [Workspace]
    let selectedWorkspaceID: String?
    @Binding var newWorkspaceTitle: String
    let onSelect: (Workspace) -> Void
    let onCreate: () -> Bool

    var body: some View {
        NavigationStack {
            List {
                existingWorkspacesSection
                createWorkspaceSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AmonTheme.canvas)
            .navigationTitle("Save Destination")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var existingWorkspacesSection: some View {
        if !workspaces.isEmpty {
            Section("Save to workspace") {
                ForEach(workspaces) { workspace in
                    Button {
                        onSelect(workspace)
                        dismiss()
                    } label: {
                        WorkspaceChooserRow(
                            workspace: workspace,
                            isSelected: workspace.id == selectedWorkspaceID
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var createWorkspaceSection: some View {
        Section {
            TextField("Workspace name", text: $newWorkspaceTitle)
                .textInputAutocapitalization(.words)

            Button("Create and use") {
                if onCreate() {
                    dismiss()
                }
            }
            .buttonStyle(AmonPrimaryButtonStyle(minHeight: 42))
            .disabled(newWorkspaceTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } header: {
            Text(workspaces.isEmpty ? "Create a workspace" : "New workspace")
        } footer: {
            Text("Saved sources, compares, and research stay organized by workspace on this device.")
        }
    }
}

private struct WorkspaceChooserRow: View {
    let workspace: Workspace
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(workspace.title)
                .font(.body.weight(.semibold))
                .foregroundStyle(AmonTheme.ink)
                Text("Updated \(AmonFormatters.relativeTimestamp(for: workspace.updatedAt))")
                    .font(.footnote)
                    .foregroundStyle(AmonTheme.muted)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AmonTheme.accent)
            }
        }
    }
}
