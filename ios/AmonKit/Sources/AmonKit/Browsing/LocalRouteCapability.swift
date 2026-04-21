import Combine
import Foundation

public enum LocalPrivacyRouteState: String, CaseIterable, Codable, Sendable {
    case unsupported
    case disconnected
    case connecting
    case connected
    case degraded
    case unavailable

    public var title: String {
        switch self {
        case .unsupported:
            return "Unsupported"
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting"
        case .connected:
            return "Connected"
        case .degraded:
            return "Degraded"
        case .unavailable:
            return "Unavailable"
        }
    }
}

public enum LocalRouteCapabilityReason: String, CaseIterable, Codable, Sendable {
    case unsupportedBuild
    case authenticationRequired
    case endpointNotConfigured
    case routeSessionMissing
    case routeSessionInvalid
    case routeSessionMintFailed
    case routeSessionExpired
    case routeSessionRevoked
    case routeSessionRefreshFailed
    case relayAuthenticationRejected
    case relayUnavailable
    case relayBootstrapMalformed
    case tunnelDisconnected
    case tunnelFailed
}

public enum LocalRouteSessionStatus: String, CaseIterable, Codable, Sendable {
    case absent
    case minting
    case active
    case refreshing
    case expired
    case revoked
    case failed
}

public enum LocalRouteRelayAuthState: String, CaseIterable, Codable, Sendable {
    case notStarted
    case pending
    case accepted
    case rejected
    case unavailable

    public var title: String {
        switch self {
        case .notStarted:
            return "Not started"
        case .pending:
            return "Pending"
        case .accepted:
            return "Accepted"
        case .rejected:
            return "Rejected"
        case .unavailable:
            return "Unavailable"
        }
    }
}

public enum LocalRouteReadinessState: String, CaseIterable, Codable, Sendable {
    case noRouteSession
    case routeSessionAcquired
    case relayAuthPending
    case relayAuthAccepted
    case relayAuthRejected
    case routeUnavailable

    public var title: String {
        switch self {
        case .noRouteSession:
            return "No route session"
        case .routeSessionAcquired:
            return "Route session acquired"
        case .relayAuthPending:
            return "Relay auth pending"
        case .relayAuthAccepted:
            return "Relay auth accepted"
        case .relayAuthRejected:
            return "Relay auth rejected"
        case .routeUnavailable:
            return "Route unavailable"
        }
    }
}

public struct LocalRouteRelayStatusSnapshot: Equatable, Hashable, Sendable {
    public let state: LocalRouteRelayAuthState
    public let code: String?
    public let detail: String?
    public let sessionID: String?
    public let productSessionID: String?
    public let authSessionID: String?
    public let expiresAt: Date?
    public let packetPlaneReady: Bool?
    public let forwardingMode: String?
    public let forwardingReady: Bool?
    public let lastUpdatedAt: Date

    public init(
        state: LocalRouteRelayAuthState,
        code: String? = nil,
        detail: String? = nil,
        sessionID: String? = nil,
        productSessionID: String? = nil,
        authSessionID: String? = nil,
        expiresAt: Date? = nil,
        packetPlaneReady: Bool? = nil,
        forwardingMode: String? = nil,
        forwardingReady: Bool? = nil,
        lastUpdatedAt: Date = Date()
    ) {
        self.state = state
        self.code = code
        self.detail = detail
        self.sessionID = sessionID
        self.productSessionID = productSessionID
        self.authSessionID = authSessionID
        self.expiresAt = expiresAt
        self.packetPlaneReady = packetPlaneReady
        self.forwardingMode = forwardingMode
        self.forwardingReady = forwardingReady
        self.lastUpdatedAt = lastUpdatedAt
    }

    public static let notStarted = LocalRouteRelayStatusSnapshot(state: .notStarted)
}

public struct LocalRouteCapabilitySnapshot: Equatable, Hashable, Sendable {
    public let state: LocalPrivacyRouteState
    public let readinessState: LocalRouteReadinessState
    public let reason: LocalRouteCapabilityReason?
    public let detail: String?
    public let routeSessionStatus: LocalRouteSessionStatus
    public let routeSessionID: String?
    public let routeSessionExpiresAt: Date?
    public let relayStatus: LocalRouteRelayStatusSnapshot
    public let tunnelStatus: TransportTunnelStatusSnapshot

    public init(
        state: LocalPrivacyRouteState,
        readinessState: LocalRouteReadinessState = .routeUnavailable,
        reason: LocalRouteCapabilityReason? = nil,
        detail: String? = nil,
        routeSessionStatus: LocalRouteSessionStatus = .absent,
        routeSessionID: String? = nil,
        routeSessionExpiresAt: Date? = nil,
        relayStatus: LocalRouteRelayStatusSnapshot = .notStarted,
        tunnelStatus: TransportTunnelStatusSnapshot = .disconnected
    ) {
        self.state = state
        self.readinessState = readinessState
        self.reason = reason
        self.detail = detail
        self.routeSessionStatus = routeSessionStatus
        self.routeSessionID = routeSessionID
        self.routeSessionExpiresAt = routeSessionExpiresAt
        self.relayStatus = relayStatus
        self.tunnelStatus = tunnelStatus
    }

    public static let unsupported = LocalRouteCapabilitySnapshot(
        state: .unsupported,
        readinessState: .routeUnavailable,
        reason: .unsupportedBuild,
        detail: "This build does not currently support routed-local browsing."
    )

    public var canRemainLocalRouted: Bool {
        state == .connected && readinessState == .relayAuthAccepted && relayStatus.state == .accepted
    }

    public var fallbackReason: String {
        if let detail, !detail.isEmpty {
            return detail
        }

        switch readinessState {
        case .noRouteSession:
            return "Amon does not currently have a routed-local session, so this open falls back to direct device browsing."
        case .routeSessionAcquired:
            return "Amon has a routed-local session, but the tunnel is not connected, so this open falls back to direct device browsing."
        case .relayAuthPending:
            return "Amon is still authenticating the local route with the relay, so this open falls back to direct device browsing until relay auth completes."
        case .relayAuthAccepted:
            break
        case .relayAuthRejected:
            return "Amon's relay rejected the routed-local session, so this open falls back to direct device browsing."
        case .routeUnavailable:
            break
        }

        switch state {
        case .unsupported:
            return "Amon local routed browsing is not supported in this build, so this open falls back to direct device browsing."
        case .disconnected:
            return "Amon local route is disconnected, so this open falls back to direct device browsing."
        case .connecting:
            return "Amon local route is still connecting, so this open falls back to direct device browsing until the route is ready."
        case .connected:
            return "Amon local route is ready."
        case .degraded:
            return "Amon local route is degraded, so this open falls back to direct device browsing."
        case .unavailable:
            return "Amon local route is unavailable, so this open falls back to direct device browsing."
        }
    }
}

@MainActor
public final class LocalRouteCapabilityController: ObservableObject {
    @Published public private(set) var capability: LocalRouteCapabilitySnapshot = .unsupported

    private let apiClient: any AmonAPIClienting
    private let now: () -> Date
    private var currentRouteSession: RouteSessionStateDTO?
    private var routeSessionStatus: LocalRouteSessionStatus = .absent
    private var routeSessionFailureReason: LocalRouteCapabilityReason?
    private var routeSessionFailureDetail: String?
    private var lastTunnelStatus: TransportTunnelStatusSnapshot = .disconnected
    private var lastRelayStatus: LocalRouteRelayStatusSnapshot = .notStarted
    private var isSynchronizingRouteSession = false

    public init(
        apiClient: any AmonAPIClienting,
        now: @escaping () -> Date = Date.init
    ) {
        self.apiClient = apiClient
        self.now = now
    }

    public func refresh(
        isAuthenticated: Bool,
        settings: TransportPrivacySettings,
        tunnelStatus: TransportTunnelStatusSnapshot,
        relayStatus: LocalRouteRelayStatusSnapshot
    ) async {
        lastTunnelStatus = tunnelStatus
        lastRelayStatus = relayStatus

        if !isAuthenticated {
            await clearRouteSessionIfNeeded(revokeRemotely: true)
            routeSessionStatus = .absent
            routeSessionFailureReason = nil
            routeSessionFailureDetail = nil
            capability = snapshot(
                state: .disconnected,
                readinessState: .routeUnavailable,
                reason: .authenticationRequired,
                detail: "Sign in to let Amon mint a routed-local session."
            )
            return
        }

        guard settings.endpoint.isConfigured else {
            await clearRouteSessionIfNeeded(revokeRemotely: true)
            routeSessionStatus = .absent
            routeSessionFailureReason = nil
            routeSessionFailureDetail = nil
            capability = snapshot(
                state: .disconnected,
                readinessState: .routeUnavailable,
                reason: .endpointNotConfigured,
                detail: "Set a tunnel endpoint before Amon can keep local browsing routed."
            )
            return
        }

        await ensureRouteSession()
        capability = resolvedSnapshot()
    }

    public func updateTunnelStatus(_ tunnelStatus: TransportTunnelStatusSnapshot) {
        lastTunnelStatus = tunnelStatus
        capability = resolvedSnapshot()
    }

    public func updateRelayStatus(_ relayStatus: LocalRouteRelayStatusSnapshot) {
        lastRelayStatus = relayStatus
        capability = resolvedSnapshot()
    }

    public func prepareForTunnelConnection(
        isAuthenticated: Bool,
        settings: TransportPrivacySettings,
        tunnelStatus: TransportTunnelStatusSnapshot,
        relayStatus: LocalRouteRelayStatusSnapshot
    ) async -> RouteSessionStateDTO? {
        await refresh(
            isAuthenticated: isAuthenticated,
            settings: settings,
            tunnelStatus: tunnelStatus,
            relayStatus: relayStatus
        )
        return activeRouteSession
    }

    public func routeSessionForTunnel() -> RouteSessionStateDTO? {
        activeRouteSession
    }

    private var activeRouteSession: RouteSessionStateDTO? {
        guard let currentRouteSession, currentRouteSession.status == .active else {
            return nil
        }
        return currentRouteSession
    }

    private func ensureRouteSession() async {
        guard !isSynchronizingRouteSession else { return }
        isSynchronizingRouteSession = true
        defer { isSynchronizingRouteSession = false }

        if let session = currentRouteSession {
            if session.status == .revoked {
                routeSessionStatus = .revoked
                routeSessionFailureReason = .routeSessionRevoked
                routeSessionFailureDetail = "The routed-local session was revoked and must be reissued."
                currentRouteSession = nil
                return
            }

            if session.expires_at <= now() {
                routeSessionStatus = .expired
                routeSessionFailureReason = .routeSessionExpired
                routeSessionFailureDetail = "The routed-local session expired and must be refreshed before browsing can stay local-routed."
                currentRouteSession = nil
            } else if session.refresh_after <= now() {
                routeSessionStatus = .refreshing
                do {
                    let refreshed = try await apiClient.refreshRouteSession(sessionID: session.session_id)
                    currentRouteSession = refreshed
                    routeSessionStatus = .active
                    routeSessionFailureReason = nil
                    routeSessionFailureDetail = nil
                } catch {
                    routeSessionStatus = .failed
                    routeSessionFailureReason = .routeSessionRefreshFailed
                    routeSessionFailureDetail = AmonErrorPresenter.message(
                        for: error,
                        fallback: "Amon couldn't refresh the routed-local session."
                    )
                    currentRouteSession = nil
                }
                return
            } else {
                routeSessionStatus = .active
                routeSessionFailureReason = nil
                routeSessionFailureDetail = nil
                return
            }
        }

        routeSessionStatus = .minting
        do {
            let minted = try await apiClient.mintRouteSession()
            currentRouteSession = minted
            routeSessionStatus = .active
            routeSessionFailureReason = nil
            routeSessionFailureDetail = nil
        } catch {
            routeSessionStatus = .failed
            routeSessionFailureReason = .routeSessionMintFailed
            routeSessionFailureDetail = AmonErrorPresenter.message(
                for: error,
                fallback: "Amon couldn't mint a routed-local session."
            )
            currentRouteSession = nil
        }
    }

    private func clearRouteSessionIfNeeded(revokeRemotely: Bool) async {
        guard let currentRouteSession else { return }
        if revokeRemotely {
            _ = try? await apiClient.revokeRouteSession(sessionID: currentRouteSession.session_id)
        }
        self.currentRouteSession = nil
    }

    private func resolvedSnapshot() -> LocalRouteCapabilitySnapshot {
        if let routeSessionFailureReason {
            let failedState: LocalPrivacyRouteState = lastTunnelStatus.state == .connected ? .degraded : .unavailable
            return snapshot(
                state: failedState,
                readinessState: .routeUnavailable,
                reason: routeSessionFailureReason,
                detail: routeSessionFailureDetail
            )
        }

        guard activeRouteSession != nil else {
            return snapshot(
                state: .unavailable,
                readinessState: .noRouteSession,
                reason: .routeSessionMissing,
                detail: "Amon does not have an active routed-local session for this device."
            )
        }

        switch lastRelayStatus.state {
        case .rejected:
            let failedState: LocalPrivacyRouteState = lastTunnelStatus.state == .connected ? .degraded : .unavailable
            return snapshot(
                state: failedState,
                readinessState: .relayAuthRejected,
                reason: capabilityReason(for: lastRelayStatus),
                detail: lastRelayStatus.detail ?? "The relay rejected the routed-local session."
            )
        case .unavailable:
            let failedState: LocalPrivacyRouteState = lastTunnelStatus.state == .connected ? .degraded : .unavailable
            return snapshot(
                state: failedState,
                readinessState: .routeUnavailable,
                reason: capabilityReason(for: lastRelayStatus),
                detail: lastRelayStatus.detail ?? "Amon could not confirm relay authentication for the routed-local session."
            )
        case .pending:
            return snapshot(
                state: .connecting,
                readinessState: .relayAuthPending,
                detail: lastRelayStatus.detail ?? "Amon is authenticating the routed-local tunnel with the relay."
            )
        case .accepted, .notStarted:
            break
        }

        switch lastTunnelStatus.state {
        case .connected:
            if lastRelayStatus.state != .accepted {
                return snapshot(
                    state: .degraded,
                    readinessState: .routeUnavailable,
                    reason: .relayUnavailable,
                    detail: "Amon connected the tunnel, but relay authentication has not been confirmed yet."
                )
            }
            return snapshot(
                state: .connected,
                readinessState: .relayAuthAccepted,
                detail: "Amon local route is connected and relay-authenticated for routed-local browsing."
            )
        case .connecting:
            return snapshot(
                state: .connecting,
                readinessState: .relayAuthPending,
                detail: "Amon local route is connecting and waiting for relay auth, so routed-local opens will fall back to direct browsing until it is ready."
            )
        case .disconnecting:
            return snapshot(
                state: .degraded,
                readinessState: .routeUnavailable,
                reason: .tunnelFailed,
                detail: "Amon local route is disconnecting, so routed-local opens currently fall back to direct browsing."
            )
        case .failed:
            return snapshot(
                state: .degraded,
                readinessState: .routeUnavailable,
                reason: .tunnelFailed,
                detail: lastTunnelStatus.detail ?? "Amon couldn't keep the local route healthy."
            )
        case .disconnected:
            return snapshot(
                state: .disconnected,
                readinessState: .routeSessionAcquired,
                reason: .tunnelDisconnected,
                detail: "Amon has a routed-local session, but the tunnel is not connected."
            )
        }
    }

    private func snapshot(
        state: LocalPrivacyRouteState,
        readinessState: LocalRouteReadinessState,
        reason: LocalRouteCapabilityReason? = nil,
        detail: String? = nil
    ) -> LocalRouteCapabilitySnapshot {
        LocalRouteCapabilitySnapshot(
            state: state,
            readinessState: readinessState,
            reason: reason,
            detail: detail,
            routeSessionStatus: routeSessionStatus,
            routeSessionID: currentRouteSession?.session_id,
            routeSessionExpiresAt: currentRouteSession?.expires_at,
            relayStatus: lastRelayStatus,
            tunnelStatus: lastTunnelStatus
        )
    }

    private func capabilityReason(for relayStatus: LocalRouteRelayStatusSnapshot) -> LocalRouteCapabilityReason {
        switch relayStatus.code {
        case "route_session_expired":
            return .routeSessionExpired
        case "route_session_revoked":
            return .routeSessionRevoked
        case "route_session_invalid",
            "route_session_context_mismatch",
            "route_auth_session_invalid",
            "route_session_malformed_token",
            "route_session_missing_token":
            return .routeSessionInvalid
        case "malformed_bootstrap_request",
            "unsupported_bootstrap_protocol",
            "unsupported_bootstrap_type",
            "relay_validation_malformed_response":
            return .relayBootstrapMalformed
        default:
            return relayStatus.state == .unavailable ? .relayUnavailable : .relayAuthenticationRejected
        }
    }
}
