import SwiftUI

public struct PrivacyAwarePageView: View {
    private let title: String
    private let url: URL
    private let apiClient: any AmonAPIClienting
    @ObservedObject private var privacySettingsStore: PrivacySettingsStore
    private let requestedMode: DefaultBrowsingMode?

    public init(
        title: String,
        url: URL,
        apiClient: any AmonAPIClienting,
        privacySettingsStore: PrivacySettingsStore,
        requestedMode: DefaultBrowsingMode? = nil
    ) {
        self.title = title
        self.url = url
        self.apiClient = apiClient
        self.privacySettingsStore = privacySettingsStore
        self.requestedMode = requestedMode
    }

    public var body: some View {
        switch requestedMode ?? privacySettingsStore.settings.browsing.defaultBrowsingMode {
        case .standard:
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
                sessionPersistence: privacySettingsStore.settings.browsing.sessionPersistence
            )

        case .protectedSession:
            ProtectedSessionPageView(
                title: title,
                url: url,
                apiClient: apiClient
            )
        }
    }
}

public struct ReaderPageView: View {
    @StateObject private var viewModel: ReaderPageViewModel
    private let url: URL
    private let sessionPersistence: BrowsingSessionPersistence
    @State private var presentedWebsite: PresentedWebsite?

    public init(
        title: String,
        url: URL,
        apiClient: any AmonAPIClienting,
        sessionPersistence: BrowsingSessionPersistence,
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
        self.url = url
        self.sessionPersistence = sessionPersistence
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
                Button("Open Site") {
                    presentedWebsite = PresentedWebsite(title: viewModel.navigationTitle, url: url)
                }
            }
        }
        .navigationDestination(item: $presentedWebsite) { destination in
            WebViewContainer(url: destination.url, sessionPersistence: sessionPersistence)
                .ignoresSafeArea()
                .navigationTitle(destination.title)
                .navigationBarTitleDisplayMode(.inline)
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
                message: "You can still open the site directly if you need the original page.",
                systemImage: "exclamationmark.triangle",
                actionTitle: "Open site",
                action: { presentedWebsite = PresentedWebsite(title: viewModel.navigationTitle, url: url) }
            )
        }
    }
}

private struct PresentedWebsite: Identifiable, Hashable {
    let title: String
    let url: URL

    var id: URL { url }
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
    private let apiClient: any AmonAPIClienting
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
            return "Sites do not interact directly with your device until you choose Open Site."
        case .savedLocalCopy:
            return "This saved copy lives on this device. Open Site only if you want the live page."
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
