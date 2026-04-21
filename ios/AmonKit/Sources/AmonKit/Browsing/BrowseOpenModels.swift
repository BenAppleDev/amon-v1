import Foundation

public enum BrowseOpenRecommendationState: Equatable, Sendable {
    case protectedRecommended
    case protectedAvailable
    case localRoutedPreferred
    case localRoutedOnly
    case decisionFetchFailed(message: String)
}

public struct BrowseOpenTarget: Hashable, Sendable {
    public let title: String
    public let url: URL

    public init(title: String, url: URL) {
        self.title = title
        self.url = url
    }
}

public struct BrowseOpenPresentedPage: Identifiable, Hashable {
    public let id = UUID()
    public let title: String
    public let url: URL
    public let pathResolution: BrowsePathResolution

    public init(title: String, url: URL, pathResolution: BrowsePathResolution) {
        self.title = title
        self.url = url
        self.pathResolution = pathResolution
    }

    public var requestedPath: BrowsePath {
        pathResolution.requestedPath
    }

    public var effectivePath: BrowsePath {
        pathResolution.effectivePath
    }

    public var localRouteState: LocalPrivacyRouteState {
        pathResolution.localRouteState
    }

    public var fallbackReason: String? {
        pathResolution.fallbackReason
    }
}

public struct BrowseOpenChoicePresentation: Identifiable {
    public let id = UUID()
    public let target: BrowseOpenTarget
    public let decision: ServeDecisionResponseDTO?
    public let decisionErrorMessage: String?
    public let localRouteState: LocalPrivacyRouteState

    public init(
        target: BrowseOpenTarget,
        decision: ServeDecisionResponseDTO?,
        decisionErrorMessage: String? = nil,
        localRouteState: LocalPrivacyRouteState = .unavailable
    ) {
        self.target = target
        self.decision = decision
        self.decisionErrorMessage = decisionErrorMessage
        self.localRouteState = localRouteState
    }

    public var recommendationState: BrowseOpenRecommendationState {
        if let decisionErrorMessage {
            return .decisionFetchFailed(message: decisionErrorMessage)
        }

        guard let decision else {
            return .decisionFetchFailed(
                message: "Amon couldn't check a recommendation right now."
            )
        }

        if preferredPath == .protectedSession {
            return .protectedRecommended
        }
        if allowedPaths.contains(.protectedSession) {
            return .protectedAvailable
        }
        if preferredPath == .localRouted {
            return .localRoutedPreferred
        }
        return .localRoutedOnly
    }

    public var dialogTitle: String {
        switch recommendationState {
        case .protectedRecommended:
            return "Protected Session Recommended"
        case .protectedAvailable:
            return "Choose Browse Path"
        case .localRoutedPreferred, .localRoutedOnly:
            return "Local Browsing"
        case .decisionFetchFailed:
            return "Choose Browse Path"
        }
    }

    public var showsProtectedSession: Bool {
        allowedPaths.contains(.protectedSession)
    }

    public var showsDirectFallback: Bool {
        allowedPaths.contains(.directFallback)
    }

    public var localRoutedTitle: String {
        switch localRouteState {
        case .connected:
            return "Open Local (Privacy Route)"
        case .connecting:
            return "Open Local (Route Connecting)"
        case .degraded, .unavailable:
            return "Open Local (Falls Back to Direct)"
        }
    }

    public var cleanViewTitle: String {
        "Open Clean View"
    }

    public var directFallbackTitle: String {
        "Open Direct (Fallback)"
    }

    public var protectedSessionTitle: String {
        recommendationState == .protectedRecommended
            ? "Open Protected Session (Recommended)"
            : "Open Protected Session"
    }

    public var message: String? {
        switch recommendationState {
        case .protectedRecommended:
            return "Amon recommends Protected Session for this page. Local browsing is still available if you prefer to render on this device. \(localRouteMessage)"
        case .protectedAvailable:
            return "Protected Session is available if you want stronger mediated isolation, but it is not required. \(localRouteMessage)"
        case .localRoutedPreferred:
            return "Amon recommends local rendering for this page, with Clean View as the retrieval-first option. \(localRouteMessage)"
        case .localRoutedOnly:
            return "Protected Session is not offered for this page right now. \(localRouteMessage)"
        case .decisionFetchFailed(let message):
            return "\(message) \(localRouteMessage)"
        }
    }

    private var preferredPath: BrowsePath? {
        decision?.normalizedPreferredBrowsePath
    }

    private var allowedPaths: Set<BrowsePath> {
        if let decision {
            return decision.normalizedAllowedBrowsePaths
        }
        return [.localRouted, .cleanView, .directFallback]
    }

    private var localRouteMessage: String {
        switch localRouteState {
        case .connected:
            return "Amon privacy route is connected for local browsing."
        case .connecting:
            return "Amon privacy route is connecting, so local browsing may temporarily degrade to direct fallback."
        case .degraded:
            return "Amon privacy route is degraded, so local browsing currently uses direct fallback."
        case .unavailable:
            return "Amon privacy route is not available in this build yet, so local browsing currently uses direct fallback."
        }
    }
}

private extension ServeDecisionResponseDTO {
    var normalizedPreferredBrowsePath: BrowsePath? {
        if let preferred_browse_path {
            return preferred_browse_path.browsePath
        }

        switch disposition {
        case .recommendProtected:
            return .protectedSession
        case .allowProtected, .allowCleanView, .allowLocal, .deny:
            return .localRouted
        }
    }

    var normalizedAllowedBrowsePaths: Set<BrowsePath> {
        if let allowed_browse_paths, !allowed_browse_paths.isEmpty {
            var mapped = Set(allowed_browse_paths.map(\.browsePath))
            mapped.insert(.directFallback)
            return mapped
        }

        switch disposition {
        case .recommendProtected, .allowProtected:
            return [.localRouted, .cleanView, .protectedSession, .directFallback]
        case .allowCleanView, .allowLocal, .deny:
            return [.localRouted, .cleanView, .directFallback]
        }
    }
}
