import SwiftUI

public struct SearchView: View {
    @ObservedObject private var viewModel: SearchViewModel
    @FocusState private var isSearchFieldFocused: Bool
    @State private var presentedPage: PresentedPage?

    public init(viewModel: SearchViewModel) {
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
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
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
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isSearchFieldFocused = false
                    }
                }
            }
            .navigationDestination(item: $presentedPage) { page in
                WebViewContainer(url: page.url)
                    .ignoresSafeArea()
                    .navigationTitle(page.title)
                    .navigationBarTitleDisplayMode(.inline)
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Private by default.")
                .font(.title.bold())
            Text("Search the web, keep what matters locally, and go deeper only when you need to.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var searchComposer: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Search")
                .font(.headline)
                .foregroundStyle(.secondary)

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
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

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
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isSearching {
            AmonEmptyStateView(
                title: "Searching",
                message: "Looking up results from the backend and preparing them for local review.",
                systemImage: "magnifyingglass.circle"
            )
        } else if viewModel.results.isEmpty {
            if viewModel.hasSearched {
                AmonEmptyStateView(
                    title: "No results yet",
                    message: "Try a broader query or a different phrase. Amon will keep the workspace local even when the search changes.",
                    systemImage: "doc.text.magnifyingglass"
                )
            } else {
                AmonEmptyStateView(
                    title: "Start a private search",
                    message: "Search is lightweight on purpose. Save the results you care about, then compare or research them when the signal is strong enough.",
                    systemImage: "square.and.arrow.down.on.square"
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
                        onOpen: {
                            guard let url = URL(string: result.url) else { return }
                            presentedPage = PresentedPage(title: result.title, url: url)
                        },
                        onSave: {
                            viewModel.save(result: result)
                        },
                        onToggleSelection: {
                            viewModel.toggleSelection(for: result.id)
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
                Button(action: viewModel.saveSelectedResults) {
                    Label("Save", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(!viewModel.canSaveSelection)

                Button {
                    Task { await viewModel.runCompare() }
                } label: {
                    Label("Compare", systemImage: "square.split.2x2")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(!viewModel.canCompare)

                Button {
                    Task { await viewModel.runResearch() }
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
        .background(Color(uiColor: .systemBackground).opacity(0.92), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color(uiColor: .separator).opacity(0.16), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 18, y: 8)
    }

    private func submitSearch() {
        guard viewModel.canSubmitSearch else { return }
        isSearchFieldFocused = false
        Task { await viewModel.search() }
    }
}

private struct PresentedPage: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let url: URL
}

private struct SearchResultCard: View {
    let result: SearchResult
    let isSelected: Bool
    let isSaved: Bool
    let isBusy: Bool
    let onOpen: () -> Void
    let onSave: () -> Void
    let onToggleSelection: () -> Void

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
                Button(action: onOpen) {
                    Label("Open", systemImage: "arrow.up.right.square")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button(action: onSave) {
                    Label(isSaved ? "Saved" : "Save", systemImage: isSaved ? "checkmark.circle" : "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(isBusy)

                if isSelected {
                    Button(action: onToggleSelection) {
                        Label("Selected", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else {
                    Button(action: onToggleSelection) {
                        Label("Select", systemImage: "checkmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
        }
        .amonCardStyle()
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor.opacity(0.35) : .clear, lineWidth: 1.5)
        )
    }
}
