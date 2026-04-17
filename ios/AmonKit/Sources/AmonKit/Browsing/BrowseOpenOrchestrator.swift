import Foundation

@MainActor
public final class BrowseOpenOrchestrator: ObservableObject {
    @Published public private(set) var presentedPage: BrowseOpenPresentedPage?
    @Published public private(set) var activeChoice: BrowseOpenChoicePresentation?

    private let apiClient: any AmonAPIClienting
    private var cachedDecisions: [String: ServeDecisionResponseDTO] = [:]
    private var pendingChoiceURLs: Set<String> = []

    public init(apiClient: any AmonAPIClienting) {
        self.apiClient = apiClient
    }

    public func isPreparingChoice(for urlString: String) -> Bool {
        pendingChoiceURLs.contains(urlString)
    }

    public func presentChoices(
        for target: BrowseOpenTarget,
        intent: ServeDecisionIntentDTO = .open
    ) async {
        let cacheKey = target.url.absoluteString

        if let cachedDecision = cachedDecisions[cacheKey] {
            activeChoice = BrowseOpenChoicePresentation(target: target, decision: cachedDecision)
            return
        }

        guard !pendingChoiceURLs.contains(cacheKey) else { return }
        pendingChoiceURLs.insert(cacheKey)
        defer { pendingChoiceURLs.remove(cacheKey) }

        let decision = try? await apiClient.serveDecision(url: cacheKey, intent: intent)
        if let decision {
            cachedDecisions[cacheKey] = decision
        }
        activeChoice = BrowseOpenChoicePresentation(target: target, decision: decision)
    }

    public func dismissChoice() {
        activeChoice = nil
    }

    public func dismissPresentedPage() {
        presentedPage = nil
    }

    public func open(_ mode: DefaultBrowsingMode, for target: BrowseOpenTarget) {
        presentedPage = BrowseOpenPresentedPage(
            title: target.title,
            url: target.url,
            requestedMode: mode
        )
        activeChoice = nil
    }

    public func open(_ mode: DefaultBrowsingMode, from choice: BrowseOpenChoicePresentation) {
        open(mode, for: choice.target)
    }
}
