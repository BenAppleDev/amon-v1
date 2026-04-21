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

public enum LocalPrivacyRouteState: String, CaseIterable, Codable, Sendable {
    case connected
    case connecting
    case degraded
    case unavailable

    public var title: String {
        switch self {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting"
        case .degraded:
            return "Degraded"
        case .unavailable:
            return "Unavailable"
        }
    }
}

public struct BrowsePathResolution: Equatable, Hashable, Sendable {
    public let requestedPath: BrowsePath
    public let effectivePath: BrowsePath
    public let localRouteState: LocalPrivacyRouteState
    public let fallbackReason: String?

    public init(
        requestedPath: BrowsePath,
        effectivePath: BrowsePath,
        localRouteState: LocalPrivacyRouteState,
        fallbackReason: String? = nil
    ) {
        self.requestedPath = requestedPath
        self.effectivePath = effectivePath
        self.localRouteState = localRouteState
        self.fallbackReason = fallbackReason
    }
}

public enum BrowsePathResolver {
    public static func resolve(
        requestedPath: BrowsePath,
        localRouteState: LocalPrivacyRouteState
    ) -> BrowsePathResolution {
        guard requestedPath == .localRouted else {
            return BrowsePathResolution(
                requestedPath: requestedPath,
                effectivePath: requestedPath,
                localRouteState: localRouteState
            )
        }

        switch localRouteState {
        case .connected, .connecting:
            return BrowsePathResolution(
                requestedPath: .localRouted,
                effectivePath: .localRouted,
                localRouteState: localRouteState
            )
        case .degraded:
            return BrowsePathResolution(
                requestedPath: .localRouted,
                effectivePath: .directFallback,
                localRouteState: localRouteState,
                fallbackReason: "Amon privacy route is degraded, so this open falls back to direct device browsing."
            )
        case .unavailable:
            return BrowsePathResolution(
                requestedPath: .localRouted,
                effectivePath: .directFallback,
                localRouteState: localRouteState,
                fallbackReason: "Amon privacy route is not available in this build yet, so local opens currently use direct fallback."
            )
        }
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

public extension LocalPrivacyRouteState {
    init(tunnelStatus: TransportTunnelStatusState) {
        switch tunnelStatus {
        case .connected:
            self = .connected
        case .connecting:
            self = .connecting
        case .disconnecting, .failed:
            self = .degraded
        case .disconnected:
            self = .unavailable
        }
    }
}
