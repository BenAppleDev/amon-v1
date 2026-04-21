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

    public var localRouteReason: LocalRouteCapabilityReason? {
        pathResolution.localRouteReason
    }

    public var localRouteDetail: String? {
        pathResolution.localRouteDetail
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
    public let localRouteCapability: LocalRouteCapabilitySnapshot

    public init(
        target: BrowseOpenTarget,
        decision: ServeDecisionResponseDTO?,
        decisionErrorMessage: String? = nil,
        localRouteCapability: LocalRouteCapabilitySnapshot = .unsupported
    ) {
        self.target = target
        self.decision = decision
        self.decisionErrorMessage = decisionErrorMessage
        self.localRouteCapability = localRouteCapability
    }

    public var recommendationState: BrowseOpenRecommendationState {
        if let decisionErrorMessage {
            return .decisionFetchFailed(message: decisionErrorMessage)
        }

        guard decision != nil else {
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
            return "Protected recommended"
        case .protectedAvailable:
            return "Choose a mode"
        case .localRoutedPreferred, .localRoutedOnly:
            return "Choose a mode"
        case .decisionFetchFailed:
            return "Choose a mode"
        }
    }

    public var showsProtectedSession: Bool {
        allowedPaths.contains(.protectedSession)
    }

    public var showsDirectFallback: Bool {
        allowedPaths.contains(.directFallback)
    }

    public var localRoutedTitle: String {
        switch localRouteCapability.state {
        case .connected:
            return "Open Local"
        case .connecting:
            return "Open Local"
        case .unsupported, .disconnected, .degraded, .unavailable:
            return "Open Local"
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
            ? "Open Protected Session"
            : "Open Protected Session"
    }

    public var message: String? {
        switch recommendationState {
        case .protectedRecommended:
            return "Protected Session is recommended for this page. Local and Clean View are still available if you want a lighter-weight open path."
        case .protectedAvailable:
            return "Choose how this page should open: local on this device, a clean readable fetch, or a protected remote session."
        case .localRoutedPreferred:
            return "Local is the default fit for this page, with Clean View available if you want readable retrieval first."
        case .localRoutedOnly:
            return "Local and Clean View are available here. Protected Session is not currently offered for this page."
        case .decisionFetchFailed(let message):
            return "\(message) You can still choose a local or clean open path."
        }
    }

    public var browseSheetTitle: String {
        target.title
    }

    public var browseSheetDomain: String {
        target.url.host() ?? target.url.absoluteString
    }

    public var browseSheetMessage: String {
        message ?? "Choose how this page should open in Amon."
    }

    public var localModeStatusLabel: String {
        switch localRouteCapability.state {
        case .connected:
            return "Privacy route"
        case .connecting:
            return "Route connecting"
        case .unsupported, .disconnected, .degraded, .unavailable:
            return "Falls back direct"
        }
    }

    public var localModeDescription: String {
        switch localRouteCapability.state {
        case .connected:
            return "Open the live site on this device through Amon's privacy route."
        case .connecting:
            return "Open locally while the route finishes connecting. A temporary direct fallback may still happen."
        case .unsupported, .disconnected, .degraded, .unavailable:
            return "Open the live site on this device. This build currently falls back to a direct load."
        }
    }

    public var cleanModeDescription: String {
        "Fetch a readable version first and avoid loading the live site unless you choose to go deeper."
    }

    public var protectedModeStatusLabel: String {
        switch recommendationState {
        case .protectedRecommended:
            return "Recommended"
        case .protectedAvailable:
            return "Remote session"
        case .localRoutedPreferred, .localRoutedOnly:
            return "Unavailable here"
        case .decisionFetchFailed:
            return "Check unavailable"
        }
    }

    public var protectedModeDescription: String {
        switch recommendationState {
        case .protectedRecommended, .protectedAvailable:
            return "Open the live site in a mediated remote session instead of directly on this device."
        case .localRoutedPreferred, .localRoutedOnly:
            return "Protected Session is still a product mode, but it is not offered for this page right now."
        case .decisionFetchFailed:
            return "Amon could not confirm Protected Session availability for this page right now."
        }
    }

    public var isProtectedSessionSelectable: Bool {
        showsProtectedSession
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
