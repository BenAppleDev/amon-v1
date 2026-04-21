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
    case routeSessionMintFailed
    case routeSessionExpired
    case routeSessionRevoked
    case routeSessionRefreshFailed
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

public struct LocalRouteCapabilitySnapshot: Equatable, Hashable, Sendable {
    public let state: LocalPrivacyRouteState
    public let reason: LocalRouteCapabilityReason?
    public let detail: String?
    public let routeSessionStatus: LocalRouteSessionStatus
    public let routeSessionID: String?
    public let routeSessionExpiresAt: Date?
    public let tunnelStatus: TransportTunnelStatusSnapshot

    public init(
        state: LocalPrivacyRouteState,
        reason: LocalRouteCapabilityReason? = nil,
        detail: String? = nil,
        routeSessionStatus: LocalRouteSessionStatus = .absent,
        routeSessionID: String? = nil,
        routeSessionExpiresAt: Date? = nil,
        tunnelStatus: TransportTunnelStatusSnapshot = .disconnected
    ) {
        self.state = state
        self.reason = reason
        self.detail = detail
        self.routeSessionStatus = routeSessionStatus
        self.routeSessionID = routeSessionID
        self.routeSessionExpiresAt = routeSessionExpiresAt
        self.tunnelStatus = tunnelStatus
    }

    public static let unsupported = LocalRouteCapabilitySnapshot(
        state: .unsupported,
        reason: .unsupportedBuild,
        detail: "This build does not currently support routed-local browsing."
    )

    public var canRemainLocalRouted: Bool {
        state == .connected
    }

    public var fallbackReason: String {
        if let detail, !detail.isEmpty {
            return detail
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
        tunnelStatus: TransportTunnelStatusSnapshot
    ) async {
        lastTunnelStatus = tunnelStatus

        if !isAuthenticated {
            await clearRouteSessionIfNeeded(revokeRemotely: true)
            routeSessionStatus = .absent
            routeSessionFailureReason = nil
            routeSessionFailureDetail = nil
            capability = snapshot(
                state: .disconnected,
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

    public func prepareForTunnelConnection(
        isAuthenticated: Bool,
        settings: TransportPrivacySettings,
        tunnelStatus: TransportTunnelStatusSnapshot
    ) async -> RouteSessionStateDTO? {
        await refresh(
            isAuthenticated: isAuthenticated,
            settings: settings,
            tunnelStatus: tunnelStatus
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
                reason: routeSessionFailureReason,
                detail: routeSessionFailureDetail
            )
        }

        guard activeRouteSession != nil else {
            return snapshot(
                state: .unavailable,
                reason: .routeSessionMissing,
                detail: "Amon does not have an active routed-local session for this device."
            )
        }

        switch lastTunnelStatus.state {
        case .connected:
            return snapshot(
                state: .connected,
                detail: "Amon local route is connected and ready for routed-local browsing."
            )
        case .connecting:
            return snapshot(
                state: .connecting,
                detail: "Amon local route is connecting, so routed-local opens will fall back to direct browsing until it is ready."
            )
        case .disconnecting:
            return snapshot(
                state: .degraded,
                reason: .tunnelFailed,
                detail: "Amon local route is disconnecting, so routed-local opens currently fall back to direct browsing."
            )
        case .failed:
            return snapshot(
                state: .degraded,
                reason: .tunnelFailed,
                detail: lastTunnelStatus.detail ?? "Amon couldn't keep the local route healthy."
            )
        case .disconnected:
            return snapshot(
                state: .disconnected,
                reason: .tunnelDisconnected,
                detail: "Amon has a routed-local session, but the tunnel is not connected."
            )
        }
    }

    private func snapshot(
        state: LocalPrivacyRouteState,
        reason: LocalRouteCapabilityReason? = nil,
        detail: String? = nil
    ) -> LocalRouteCapabilitySnapshot {
        LocalRouteCapabilitySnapshot(
            state: state,
            reason: reason,
            detail: detail,
            routeSessionStatus: routeSessionStatus,
            routeSessionID: currentRouteSession?.session_id,
            routeSessionExpiresAt: currentRouteSession?.expires_at,
            tunnelStatus: lastTunnelStatus
        )
    }
}
