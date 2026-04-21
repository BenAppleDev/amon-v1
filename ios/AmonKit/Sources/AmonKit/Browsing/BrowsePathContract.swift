import Foundation

public enum BrowsePath: String, CaseIterable, Codable, Sendable {
    case localRouted = "local_routed"
    case cleanView = "clean_view"
    case protectedSession = "protected_session"
    case directFallback = "direct_fallback"

    public var title: String {
        switch self {
        case .localRouted:
            return "Local (Privacy Route)"
        case .cleanView:
            return "Clean View"
        case .protectedSession:
            return "Protected Session"
        case .directFallback:
            return "Direct (Fallback)"
        }
    }
}

public struct BrowsePathResolution: Equatable, Hashable, Sendable {
    public let requestedPath: BrowsePath
    public let effectivePath: BrowsePath
    public let localRouteState: LocalPrivacyRouteState
    public let localRouteReadinessState: LocalRouteReadinessState
    public let localRouteRelayAuthState: LocalRouteRelayAuthState
    public let localRouteReason: LocalRouteCapabilityReason?
    public let localRouteDetail: String?
    public let fallbackReason: String?

    public init(
        requestedPath: BrowsePath,
        effectivePath: BrowsePath,
        localRouteState: LocalPrivacyRouteState,
        localRouteReadinessState: LocalRouteReadinessState = .routeUnavailable,
        localRouteRelayAuthState: LocalRouteRelayAuthState = .notStarted,
        localRouteReason: LocalRouteCapabilityReason? = nil,
        localRouteDetail: String? = nil,
        fallbackReason: String? = nil
    ) {
        self.requestedPath = requestedPath
        self.effectivePath = effectivePath
        self.localRouteState = localRouteState
        self.localRouteReadinessState = localRouteReadinessState
        self.localRouteRelayAuthState = localRouteRelayAuthState
        self.localRouteReason = localRouteReason
        self.localRouteDetail = localRouteDetail
        self.fallbackReason = fallbackReason
    }
}

public enum BrowsePathResolver {
    public static func resolve(
        requestedPath: BrowsePath,
        localRouteCapability: LocalRouteCapabilitySnapshot
    ) -> BrowsePathResolution {
        guard requestedPath == .localRouted else {
            return BrowsePathResolution(
                requestedPath: requestedPath,
                effectivePath: requestedPath,
                localRouteState: localRouteCapability.state,
                localRouteReadinessState: localRouteCapability.readinessState,
                localRouteRelayAuthState: localRouteCapability.relayStatus.state,
                localRouteReason: localRouteCapability.reason,
                localRouteDetail: localRouteCapability.detail
            )
        }

        if localRouteCapability.canRemainLocalRouted {
            return BrowsePathResolution(
                requestedPath: .localRouted,
                effectivePath: .localRouted,
                localRouteState: localRouteCapability.state,
                localRouteReadinessState: localRouteCapability.readinessState,
                localRouteRelayAuthState: localRouteCapability.relayStatus.state,
                localRouteReason: localRouteCapability.reason,
                localRouteDetail: localRouteCapability.detail
            )
        }

        return BrowsePathResolution(
            requestedPath: .localRouted,
            effectivePath: .directFallback,
            localRouteState: localRouteCapability.state,
            localRouteReadinessState: localRouteCapability.readinessState,
            localRouteRelayAuthState: localRouteCapability.relayStatus.state,
            localRouteReason: localRouteCapability.reason,
            localRouteDetail: localRouteCapability.detail,
            fallbackReason: localRouteCapability.fallbackReason
        )
    }
}

public extension BrowsePath {
    init(dto: BrowsePathDTO) {
        switch dto {
        case .localRouted:
            self = .localRouted
        case .cleanView:
            self = .cleanView
        case .protectedSession:
            self = .protectedSession
        case .directFallback:
            self = .directFallback
        }
    }
}

public extension BrowsePathDTO {
    var browsePath: BrowsePath {
        BrowsePath(dto: self)
    }
}

public extension DefaultBrowsingMode {
    var preferredBrowsePath: BrowsePath {
        switch self {
        case .standard:
            return .localRouted
        case .cleanView:
            return .cleanView
        case .protectedSession:
            return .protectedSession
        }
    }
}
