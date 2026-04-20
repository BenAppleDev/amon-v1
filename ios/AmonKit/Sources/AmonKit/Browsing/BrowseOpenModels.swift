import Foundation

public enum BrowseOpenRecommendationState: Equatable, Sendable {
    case protectedRecommended
    case protectedAvailable
    case localPreferred
    case localOnly
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
    public let requestedMode: DefaultBrowsingMode?

    public init(title: String, url: URL, requestedMode: DefaultBrowsingMode?) {
        self.title = title
        self.url = url
        self.requestedMode = requestedMode
    }
}

public struct BrowseOpenChoicePresentation: Identifiable {
    public let id = UUID()
    public let target: BrowseOpenTarget
    public let decision: ServeDecisionResponseDTO?
    public let decisionErrorMessage: String?

    public init(
        target: BrowseOpenTarget,
        decision: ServeDecisionResponseDTO?,
        decisionErrorMessage: String? = nil
    ) {
        self.target = target
        self.decision = decision
        self.decisionErrorMessage = decisionErrorMessage
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

        switch decision.disposition {
        case .recommendProtected:
            return .protectedRecommended
        case .allowProtected:
            return .protectedAvailable
        case .allowCleanView:
            return .localPreferred
        case .allowLocal, .deny:
            return .localOnly
        }
    }

    public var dialogTitle: String {
        switch recommendationState {
        case .protectedRecommended:
            return "Protected Session Recommended"
        case .protectedAvailable:
            return "Choose How to Open"
        case .localPreferred:
            return "Open on This Device"
        case .localOnly:
            return "Open Locally"
        case .decisionFetchFailed:
            return "Open on This Device"
        }
    }

    public var showsProtectedSession: Bool {
        switch recommendationState {
        case .protectedRecommended, .protectedAvailable:
            return true
        case .localPreferred, .localOnly, .decisionFetchFailed:
            return false
        }
    }

    public var standardTitle: String {
        switch recommendationState {
        case .localPreferred, .localOnly, .decisionFetchFailed:
            return "Open Normally (Local)"
        case .protectedRecommended, .protectedAvailable:
            return "Open Normally"
        }
    }

    public var cleanViewTitle: String {
        switch recommendationState {
        case .localPreferred, .localOnly, .decisionFetchFailed:
            return "Open Clean View (Local)"
        case .protectedRecommended, .protectedAvailable:
            return "Open Clean View"
        }
    }

    public var protectedSessionTitle: String {
        recommendationState == .protectedRecommended
            ? "Open Protected Session (Recommended)"
            : "Open Protected Session"
    }

    public var message: String? {
        switch recommendationState {
        case .protectedRecommended:
            return "Amon recommends Protected Session for this page. You still choose whether to open it remotely, use Clean View, or stay fully local."
        case .protectedAvailable:
            return "Protected Session is available here if you want stronger isolation, but Amon is not recommending it over a local open."
        case .localPreferred:
            return "Amon recommends keeping this page on your device. Clean View is available if you want a cleaner local copy."
        case .localOnly:
            return "This page stays on-device in this build. You can open it normally or use Clean View, but Protected Session is not offered."
        case .decisionFetchFailed(let message):
            return "\(message) Amon will keep this as a local choice for now."
        }
    }
}
