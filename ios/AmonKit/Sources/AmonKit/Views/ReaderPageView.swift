import SwiftUI

public struct PrivacyAwarePageView: View {
    private let title: String
    private let url: URL
    private let apiClient: any AmonAPIClienting
    @ObservedObject private var privacySettingsStore: PrivacySettingsStore
    private let requestedPath: BrowsePath?
    private let resolvedPath: BrowsePath?
    private let localRouteState: LocalPrivacyRouteState
    private let localRouteDetail: String?
    private let fallbackReason: String?

    public init(
        title: String,
        url: URL,
        apiClient: any AmonAPIClienting,
        privacySettingsStore: PrivacySettingsStore,
        requestedPath: BrowsePath? = nil,
        resolvedPath: BrowsePath? = nil,
        localRouteState: LocalPrivacyRouteState = .unsupported,
        localRouteDetail: String? = nil,
        fallbackReason: String? = nil
    ) {
        self.title = title
        self.url = url
        self.apiClient = apiClient
        self.privacySettingsStore = privacySettingsStore
        self.requestedPath = requestedPath
        self.resolvedPath = resolvedPath
        self.localRouteState = localRouteState
        self.localRouteDetail = localRouteDetail
        self.fallbackReason = fallbackReason
    }

    public var body: some View {
        switch openResolution.effectivePath {
        case .localRouted, .directFallback:
            WebViewContainer(
                url: url,
                sessionPersistence: privacySettingsStore.settings.browsing.sessionPersistence
            )
            .ignoresSafeArea()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)

        case .cleanView:
            ReaderPageView(
                title: title,
                url: url,
                apiClient: apiClient,
                privacySettingsStore: privacySettingsStore,
                localRouteCapabilityProvider: {
                    LocalRouteCapabilitySnapshot(
                        state: openResolution.localRouteState,
                        readinessState: openResolution.localRouteReadinessState,
                        reason: openResolution.localRouteReason,
                        detail: openResolution.localRouteDetail,
                        relayStatus: LocalRouteRelayStatusSnapshot(state: openResolution.localRouteRelayAuthState),
                        tunnelStatus: .disconnected
                    )
                }
            )

        case .protectedSession:
            ProtectedSessionPageView(
                title: title,
                url: url,
                apiClient: apiClient
            )
        }
    }

    private var openResolution: BrowsePathResolution {
        if let requestedPath {
            return BrowsePathResolution(
                requestedPath: requestedPath,
                effectivePath: resolvedPath ?? requestedPath,
                localRouteState: localRouteState,
                localRouteDetail: localRouteDetail,
                fallbackReason: fallbackReason
            )
        }

        return BrowsePathResolver.resolve(
            requestedPath: privacySettingsStore.settings.browsing.defaultBrowsingMode.preferredBrowsePath,
            localRouteCapability: LocalRouteCapabilitySnapshot(
                state: localRouteState,
                detail: localRouteDetail,
                tunnelStatus: .disconnected
            )
        )
    }
}

public struct ReaderPageView: View {
    @StateObject private var viewModel: ReaderPageViewModel
    @StateObject private var browseOpenOrchestrator: BrowseOpenOrchestrator
    @ObservedObject private var privacySettingsStore: PrivacySettingsStore
    private let url: URL

    public init(
        title: String,
        url: URL,
        apiClient: any AmonAPIClienting,
        privacySettingsStore: PrivacySettingsStore,
        localRouteCapabilityProvider: @escaping () -> LocalRouteCapabilitySnapshot = { .unsupported },
        initialPage: StructuredRetrievalDTO? = nil
    ) {
        _viewModel = StateObject(
            wrappedValue: ReaderPageViewModel(
                title: title,
                url: url,
                apiClient: apiClient,
                initialPage: initialPage
            )
        )
        _browseOpenOrchestrator = StateObject(
            wrappedValue: BrowseOpenOrchestrator(
                apiClient: apiClient,
                localRouteCapabilityProvider: localRouteCapabilityProvider
            )
        )
        self.privacySettingsStore = privacySettingsStore
        self.url = url
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                AmonTrustStripView(
                    items: viewModel.trustStripItems
                )

                if let banner = viewModel.banner {
                    AmonBannerView(banner: banner, dismiss: viewModel.dismissBanner)
                }

                content
            }
            .padding(20)
        }
        .background(AmonTheme.canvas.ignoresSafeArea())
        .navigationTitle(viewModel.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isPreparingOpenChoices ? "Checking..." : "Open Site") {
                    Task {
                        await presentSiteChoices()
                    }
                }
                .disabled(isPreparingOpenChoices)
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
            Button(recommendation.localRoutedTitle) {
                browseOpenOrchestrator.open(.localRouted, from: recommendation)
            }

            Button(recommendation.cleanViewTitle) {
                browseOpenOrchestrator.open(.cleanView, from: recommendation)
            }

            if recommendation.showsProtectedSession {
                Button(recommendation.protectedSessionTitle) {
                    browseOpenOrchestrator.open(.protectedSession, from: recommendation)
                }
            }

            if recommendation.showsDirectFallback {
                Button(recommendation.directFallbackTitle) {
                    browseOpenOrchestrator.open(.directFallback, from: recommendation)
                }
            }
        } message: { recommendation in
            if let message = recommendation.message {
                Text(message)
            }
        }
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            AmonEmptyStateView(
                title: "Preparing a clean view",
                message: "Amon is fetching readable content from the backend.",
                systemImage: "doc.text.magnifyingglass"
            )
        } else if let page = viewModel.page {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(page.title)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(page.domain)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(viewModel.pageIntroMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .amonCardStyle(padding: 20)

                if let excerpt = page.excerpt, !excerpt.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Readable summary")
                            .font(.headline)
                        Text(excerpt)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .amonCardStyle()
                }

                if !page.bullet_points.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Key points")
                            .font(.headline)

                        ForEach(Array(page.bullet_points.enumerated()), id: \.offset) { _, bullet in
                            HStack(alignment: .top, spacing: 10) {
                                Circle()
                                    .fill(Color.accentColor)
                                    .frame(width: 7, height: 7)
                                    .padding(.top, 7)
                                Text(bullet)
                                    .font(.body)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .amonCardStyle()
                }
            }
        } else {
            AmonEmptyStateView(
                title: "Couldn’t prepare a clean view",
                message: "You can still open the live site and choose a browse path for it.",
                systemImage: "exclamationmark.triangle",
                actionTitle: "Open site options",
                action: {
                    Task {
                        await presentSiteChoices()
                    }
                }
            )
        }
    }

    private var isPreparingOpenChoices: Bool {
        browseOpenOrchestrator.isPreparingChoice(for: url.absoluteString)
    }

    private func presentSiteChoices() async {
        await browseOpenOrchestrator.presentChoices(
            for: BrowseOpenTarget(title: viewModel.navigationTitle, url: url)
        )
    }
}

@MainActor
private final class ReaderPageViewModel: ObservableObject {
    enum ContentSource {
        case backendFetch
        case savedLocalCopy
    }

    @Published private(set) var page: StructuredRetrievalDTO?
    @Published private(set) var isLoading = false
    @Published var banner: AmonBanner?

    private let title: String
    private let url: URL
    let apiClient: any AmonAPIClienting
    private let contentSource: ContentSource
    private var didLoad = false

    init(
        title: String,
        url: URL,
        apiClient: any AmonAPIClienting,
        initialPage: StructuredRetrievalDTO? = nil
    ) {
        self.title = title
        self.url = url
        self.apiClient = apiClient
        self.page = initialPage
        self.contentSource = initialPage == nil ? .backendFetch : .savedLocalCopy
        self.didLoad = initialPage != nil
    }

    var navigationTitle: String {
        page?.title ?? title
    }

    var trustStripItems: [String] {
        switch contentSource {
        case .backendFetch:
            return [
                "Reader fetch",
                "Fresh backend request",
                "No direct site load unless you open it",
            ]
        case .savedLocalCopy:
            return [
                "Saved locally",
                "No backend fetch",
                "Open Site is optional",
            ]
        }
    }

    var pageIntroMessage: String {
        switch contentSource {
        case .backendFetch:
            return "Sites do not interact directly with your device until you choose Open Site and a browse path."
        case .savedLocalCopy:
            return "This saved copy lives on this device. Open Site only if you want the live page and path options."
        }
    }

    func loadIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true
        isLoading = true
        defer { isLoading = false }

        do {
            page = try await apiClient.retrieve(url: url.absoluteString)
            banner = nil
        } catch {
            page = nil
            banner = AmonBanner(
                tone: .error,
                title: "Reader view unavailable",
                message: AmonErrorPresenter.message(
                    for: error,
                    fallback: "Amon couldn't fetch readable content for that page."
                )
            )
        }
    }

    func dismissBanner() {
        banner = nil
    }
}
