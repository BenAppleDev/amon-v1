import SwiftUI

public struct SearchView: View {
    @ObservedObject private var viewModel: SearchViewModel
    @ObservedObject private var privacySettingsStore: PrivacySettingsStore
    private let openAppMenu: () -> Void
    @FocusState private var isSearchFieldFocused: Bool
    @State private var presentedPage: PresentedPage?
    @State private var openRecommendation: OpenRecommendationPresentation?
    @State private var serveDecisionCache: [String: ServeDecisionResponseDTO] = [:]
    @State private var decidingOpenResultID: String?
    @State private var isPresentingWorkspaceChooser = false
    @State private var newWorkspaceTitle = ""
    @State private var pendingWorkspaceAction: PendingWorkspaceAction?

    public init(
        viewModel: SearchViewModel,
        privacySettingsStore: PrivacySettingsStore,
        openAppMenu: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.privacySettingsStore = privacySettingsStore
        self.openAppMenu = openAppMenu
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AmonTheme.canvas
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        searchComposer
                        AmonTrustStripView(items: ["Saved locally", "No server history"])

                        if let banner = viewModel.banner {
                            AmonBannerView(banner: banner, dismiss: viewModel.dismissBanner)
                        }

                        content
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, viewModel.shouldShowSelectionBar ? 120 : 32)
                }
                .scrollDismissesKeyboard(.interactively)
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
            .navigationDestination(item: $presentedPage) { page in
                PrivacyAwarePageView(
                    title: page.title,
                    url: page.url,
                    apiClient: viewModel.apiClient,
                    privacySettingsStore: privacySettingsStore,
                    requestedMode: page.requestedMode
                )
            }
            .confirmationDialog(
                openRecommendation?.dialogTitle ?? "Open",
                isPresented: Binding(
                    get: { openRecommendation != nil },
                    set: { isPresented in
                        if !isPresented {
                            openRecommendation = nil
                        }
                    }
                ),
                titleVisibility: .visible,
                presenting: openRecommendation
            ) { recommendation in
                Button("Open Normally") {
                    openPage(title: recommendation.title, url: recommendation.url, mode: .standard)
                }

                Button("Clean View") {
                    openPage(title: recommendation.title, url: recommendation.url, mode: .cleanView)
                }

                if recommendation.showsProtectedSession {
                    Button(recommendation.protectedSessionTitle) {
                        openPage(title: recommendation.title, url: recommendation.url, mode: .protectedSession)
                    }
                }
            } message: { recommendation in
                if let message = recommendation.message {
                    Text(message)
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
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search the web privately", text: $viewModel.query)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .submitLabel(.search)
                        .focused($isSearchFieldFocused)
                        .onSubmit {
                            submitSearch()
                        }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(AmonTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(AmonTheme.border.opacity(0.85), lineWidth: 1)
                )

                Button(action: submitSearch) {
                    if viewModel.isSearching {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Text("Search")
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
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
                    .foregroundStyle(viewModel.currentWorkspace == nil ? Color.accentColor : .primary)
                    .frame(width: 34, height: 34)
                    .background(
                        (viewModel.currentWorkspace == nil ? Color.accentColor.opacity(0.12) : AmonTheme.pillSurface),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.currentWorkspaceTitle ?? "Choose a workspace")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(viewModel.currentWorkspaceSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 12)

                Text(viewModel.workspaceChooserButtonTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .amonCardStyle(padding: 14)
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
            LazyVStack(spacing: 14) {
                ForEach(viewModel.results, id: \.id) { result in
                        SearchResultCard(
                            result: result,
                            isSelected: viewModel.isSelected(result),
                            isSaved: viewModel.isSaved(result),
                            isBusy: viewModel.isSavingLocally || viewModel.isRunningCompare || viewModel.isRunningResearch,
                            isPreparingOpenChoice: decidingOpenResultID == result.id,
                            onOpenChooser: {
                                presentOpenOptions(for: result)
                            },
                            onOpenNormally: {
                                guard let url = URL(string: result.url) else { return }
                                openPage(title: result.title, url: url, mode: .standard)
                            },
                            onOpenCleanView: {
                                guard let url = URL(string: result.url) else { return }
                                openPage(title: result.title, url: url, mode: .cleanView)
                            },
                            onOpenProtected: {
                                guard let url = URL(string: result.url) else { return }
                                openPage(title: result.title, url: url, mode: .protectedSession)
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
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button {
                    runAction(.saveSelection)
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(!viewModel.canSaveSelection)

                Button {
                    AmonHaptics.softImpact()
                    runAction(.compare)
                } label: {
                    Label("Compare", systemImage: "square.split.2x2")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(!viewModel.canCompare)

                Button {
                    AmonHaptics.softImpact()
                    runAction(.research)
                } label: {
                    Label("Research", systemImage: "text.magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!viewModel.canResearch)
            }
        }
        .padding(16)
        .background(AmonTheme.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(AmonTheme.border.opacity(0.85), lineWidth: 1)
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

    private func presentOpenOptions(for result: SearchResult) {
        guard let url = URL(string: result.url) else { return }

        if let cachedDecision = serveDecisionCache[result.url] {
            openRecommendation = OpenRecommendationPresentation(
                title: result.title,
                url: url,
                decision: cachedDecision
            )
            return
        }

        guard decidingOpenResultID == nil else { return }
        decidingOpenResultID = result.id

        Task {
            let decision = try? await viewModel.apiClient.serveDecision(url: result.url, intent: .open)
            await MainActor.run {
                decidingOpenResultID = nil
                if let decision {
                    serveDecisionCache[result.url] = decision
                }
                openRecommendation = OpenRecommendationPresentation(
                    title: result.title,
                    url: url,
                    decision: decision
                )
            }
        }
    }

    private func openPage(title: String, url: URL, mode: DefaultBrowsingMode) {
        presentedPage = PresentedPage(title: title, url: url, requestedMode: mode)
        openRecommendation = nil
    }
}

private struct PresentedPage: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let url: URL
    let requestedMode: DefaultBrowsingMode?
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
    let onOpenNormally: () -> Void
    let onOpenCleanView: () -> Void
    let onOpenProtected: () -> Void
    let onSave: () -> Void
    let onToggleSelection: () -> Void
    let onQuickCompare: () -> Void
    let onQuickResearch: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(result.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(result.domain)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.accentColor)
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
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                Button(action: onOpenChooser) {
                    AmonActionChip(
                        title: isPreparingOpenChoice ? "Checking..." : "Open",
                        systemImage: isPreparingOpenChoice ? "ellipsis.circle" : "arrow.up.right.square"
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
                            tone: .accent
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
        .amonCardStyle()
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor.opacity(0.35) : .clear, lineWidth: 1.5)
        )
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .contextMenu {
            Button(action: onOpenChooser) {
                Label("Choose How to Open", systemImage: "arrow.up.right.square")
            }

            Button(action: onOpenNormally) {
                Label("Open Normally", systemImage: "arrow.up.right.square")
            }

            Button(action: onOpenCleanView) {
                Label("Clean View", systemImage: "doc.text")
            }

            Button(action: onOpenProtected) {
                Label("Open Protected Session", systemImage: "lock.shield")
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

private struct OpenRecommendationPresentation: Identifiable {
    let id = UUID()
    let title: String
    let url: URL
    let decision: ServeDecisionResponseDTO?

    var dialogTitle: String {
        "Choose How to Open"
    }

    var showsProtectedSession: Bool {
        guard let disposition = decision?.disposition else { return false }
        switch disposition {
        case .recommendProtected, .allowProtected:
            return true
        case .allowLocal, .allowCleanView, .deny:
            return false
        }
    }

    var protectedSessionTitle: String {
        decision?.disposition == .recommendProtected
            ? "Open Protected Session (Recommended)"
            : "Open Protected Session"
    }

    var message: String? {
        guard let decision else {
            return "Amon couldn't fetch a recommendation, so this stays a local choice."
        }

        switch decision.disposition {
        case .recommendProtected:
            return "Amon recommends Protected Session for this site in this build. You still choose how to open it."
        case .allowCleanView:
            return "Protected Session isn't recommended for this site. Open it normally or use Clean View."
        case .allowLocal, .deny:
            return "Open on this device is recommended for this site. Protected Session stays off unless Amon explicitly recommends it."
        case .allowProtected:
            return "Protected Session is available for this site if you want it, but Amon isn't forcing mediation."
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
                    .foregroundStyle(.primary)
                Text("Updated \(AmonFormatters.relativeTimestamp(for: workspace.updatedAt))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accentColor)
            }
        }
    }
}
