import Foundation

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

    public init(target: BrowseOpenTarget, decision: ServeDecisionResponseDTO?) {
        self.target = target
        self.decision = decision
    }

    public var dialogTitle: String {
        "Choose How to Open"
    }

    public var showsProtectedSession: Bool {
        guard let disposition = decision?.disposition else { return false }
        switch disposition {
        case .recommendProtected, .allowProtected:
            return true
        case .allowLocal, .allowCleanView, .deny:
            return false
        }
    }

    public var protectedSessionTitle: String {
        decision?.disposition == .recommendProtected
            ? "Open Protected Session (Recommended)"
            : "Open Protected Session"
    }

    public var message: String? {
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
