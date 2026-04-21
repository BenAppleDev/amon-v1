import Foundation

@MainActor
public final class BrowseOpenOrchestrator: ObservableObject {
    @Published public private(set) var presentedPage: BrowseOpenPresentedPage?
    @Published public private(set) var activeChoice: BrowseOpenChoicePresentation?

    private let apiClient: any AmonAPIClienting
    private let localRouteStateProvider: () -> LocalPrivacyRouteState
    private var cachedDecisions: [String: ServeDecisionResponseDTO] = [:]
    private var pendingChoiceURLs: Set<String> = []

    public init(
        apiClient: any AmonAPIClienting,
        localRouteStateProvider: @escaping () -> LocalPrivacyRouteState = { .unavailable }
    ) {
        self.apiClient = apiClient
        self.localRouteStateProvider = localRouteStateProvider
    }

    public func isPreparingChoice(for urlString: String) -> Bool {
        pendingChoiceURLs.contains(urlString)
    }

    public func presentChoices(
        for target: BrowseOpenTarget,
        intent: ServeDecisionIntentDTO = .open
    ) async {
        let cacheKey = target.url.absoluteString
        let localRouteState = localRouteStateProvider()

        if let cachedDecision = cachedDecisions[cacheKey] {
            activeChoice = BrowseOpenChoicePresentation(
                target: target,
                decision: cachedDecision,
                localRouteState: localRouteState
            )
            return
        }

        guard !pendingChoiceURLs.contains(cacheKey) else { return }
        pendingChoiceURLs.insert(cacheKey)
        defer { pendingChoiceURLs.remove(cacheKey) }

        do {
            let decision = try await apiClient.serveDecision(url: cacheKey, intent: intent)
            cachedDecisions[cacheKey] = decision
            activeChoice = BrowseOpenChoicePresentation(
                target: target,
                decision: decision,
                localRouteState: localRouteState
            )
        } catch {
            activeChoice = BrowseOpenChoicePresentation(
                target: target,
                decision: nil,
                decisionErrorMessage: AmonErrorPresenter.message(
                    for: error,
                    fallback: "Amon couldn't check a recommendation right now."
                ),
                localRouteState: localRouteState
            )
        }
    }

    public func dismissChoice() {
        activeChoice = nil
    }

    public func dismissPresentedPage() {
        presentedPage = nil
    }

    public func open(_ path: BrowsePath, for target: BrowseOpenTarget) {
        let resolution = BrowsePathResolver.resolve(
            requestedPath: path,
            localRouteState: localRouteStateProvider()
        )
        presentedPage = BrowseOpenPresentedPage(
            title: target.title,
            url: target.url,
            pathResolution: resolution
        )
        activeChoice = nil
    }

    public func open(_ path: BrowsePath, from choice: BrowseOpenChoicePresentation) {
        open(path, for: choice.target)
    }
}
