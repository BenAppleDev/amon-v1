import XCTest
@testable import AmonKit

@MainActor
final class LocalRouteCapabilityControllerTests: XCTestCase {
    func testRefreshReportsDisconnectedWhenAuthenticationIsMissing() async {
        let apiClient = LocalRouteCapabilityMockAPIClient()
        let controller = LocalRouteCapabilityController(apiClient: apiClient)

        await controller.refresh(
            isAuthenticated: false,
            settings: .init(),
            tunnelStatus: .disconnected,
            relayStatus: .notStarted
        )

        XCTAssertEqual(controller.capability.state, .disconnected)
        XCTAssertEqual(controller.capability.reason, .authenticationRequired)
        XCTAssertEqual(apiClient.mintRouteSessionCallCount, 0)
    }

    func testRefreshMintsRouteSessionAndReportsDisconnectedUntilTunnelConnects() async {
        let apiClient = LocalRouteCapabilityMockAPIClient()
        let controller = LocalRouteCapabilityController(apiClient: apiClient)

        await controller.refresh(
            isAuthenticated: true,
            settings: configuredSettings(),
            tunnelStatus: .disconnected,
            relayStatus: .notStarted
        )

        XCTAssertEqual(apiClient.mintRouteSessionCallCount, 1)
        XCTAssertEqual(controller.capability.state, .disconnected)
        XCTAssertEqual(controller.capability.reason, .tunnelDisconnected)
        XCTAssertEqual(controller.capability.readinessState, .routeSessionAcquired)
        XCTAssertEqual(controller.capability.routeSessionStatus, .active)
        XCTAssertEqual(controller.capability.relayStatus.state, .notStarted)
        XCTAssertNotNil(controller.routeSessionForTunnel())
    }

    func testRefreshUsesConnectingAndConnectedTunnelStatesWhenRouteSessionIsActive() async {
        let apiClient = LocalRouteCapabilityMockAPIClient()
        let controller = LocalRouteCapabilityController(apiClient: apiClient)

        await controller.refresh(
            isAuthenticated: true,
            settings: configuredSettings(),
            tunnelStatus: TransportTunnelStatusSnapshot(state: .connecting),
            relayStatus: LocalRouteRelayStatusSnapshot(state: .pending)
        )
        XCTAssertEqual(controller.capability.state, .connecting)
        XCTAssertEqual(controller.capability.readinessState, .relayAuthPending)

        controller.updateRelayStatus(LocalRouteRelayStatusSnapshot(state: .accepted))
        controller.updateTunnelStatus(TransportTunnelStatusSnapshot(state: .connected))
        XCTAssertEqual(controller.capability.state, .connected)
        XCTAssertEqual(controller.capability.readinessState, .relayAuthAccepted)
        XCTAssertTrue(controller.capability.canRemainLocalRouted)
    }

    func testRefreshReportsUnavailableWhenMintFails() async {
        let apiClient = LocalRouteCapabilityMockAPIClient()
        apiClient.mintRouteSessionError = AmonAPIError.serverError(
            AmonBackendErrorContext(
                statusCode: 503,
                code: "route_session_unavailable",
                message: "The routed-local control plane is unavailable."
            )
        )
        let controller = LocalRouteCapabilityController(apiClient: apiClient)

        await controller.refresh(
            isAuthenticated: true,
            settings: configuredSettings(),
            tunnelStatus: .disconnected,
            relayStatus: .notStarted
        )

        XCTAssertEqual(controller.capability.state, .unavailable)
        XCTAssertEqual(controller.capability.reason, .routeSessionMintFailed)
        XCTAssertNil(controller.routeSessionForTunnel())
    }

    func testRefreshUsesRefreshEndpointWhenLeaseNeedsRotation() async {
        let baseNow = Date(timeIntervalSince1970: 1_700_000_000)
        let apiClient = LocalRouteCapabilityMockAPIClient(now: baseNow)
        let controller = LocalRouteCapabilityController(apiClient: apiClient, now: { baseNow.addingTimeInterval(120) })

        await controller.refresh(
            isAuthenticated: true,
            settings: configuredSettings(),
            tunnelStatus: .disconnected,
            relayStatus: .notStarted
        )

        await controller.refresh(
            isAuthenticated: true,
            settings: configuredSettings(),
            tunnelStatus: .disconnected,
            relayStatus: .notStarted
        )

        XCTAssertEqual(apiClient.mintRouteSessionCallCount, 1)
        XCTAssertEqual(apiClient.refreshRouteSessionCallCount, 1)
        XCTAssertEqual(controller.capability.routeSessionStatus, .active)
    }

    func testRefreshReportsRelayRejectionEvenWhenTunnelIsConnected() async {
        let apiClient = LocalRouteCapabilityMockAPIClient()
        let controller = LocalRouteCapabilityController(apiClient: apiClient)

        await controller.refresh(
            isAuthenticated: true,
            settings: configuredSettings(),
            tunnelStatus: TransportTunnelStatusSnapshot(state: .connected),
            relayStatus: LocalRouteRelayStatusSnapshot(
                state: .rejected,
                code: "route_session_expired",
                detail: "The relay rejected the routed-local session because it expired."
            )
        )

        XCTAssertEqual(controller.capability.state, .degraded)
        XCTAssertEqual(controller.capability.readinessState, .relayAuthRejected)
        XCTAssertEqual(controller.capability.reason, .routeSessionExpired)
        XCTAssertFalse(controller.capability.canRemainLocalRouted)
    }

    private func configuredSettings() -> TransportPrivacySettings {
        TransportPrivacySettings(
            enabledWhenSignedIn: true,
            autoConnectOnSessionRestore: true,
            endpoint: TransportTunnelEndpointSettings(serverHost: "192.168.1.44")
        )
    }
}

private final class LocalRouteCapabilityMockAPIClient: @unchecked Sendable, AmonAPIClienting {
    var mintRouteSessionCallCount = 0
    var refreshRouteSessionCallCount = 0
    var revokeRouteSessionCallCount = 0
    var mintRouteSessionError: Error?
    var refreshRouteSessionError: Error?
    private let now: Date

    init(now: Date = Date()) {
        self.now = now
    }

    func devLogin(appleSubject _: String) async throws -> AuthResponseDTO {
        fatalError("not used")
    }

    func me() async throws -> UserDTO {
        fatalError("not used")
    }

    func search(query _: String, count _: Int) async throws -> [SearchResult] {
        fatalError("not used")
    }

    func retrieve(url _: String) async throws -> StructuredRetrievalDTO {
        fatalError("not used")
    }

    func serveDecision(url _: String, intent _: ServeDecisionIntentDTO) async throws -> ServeDecisionResponseDTO {
        fatalError("not used")
    }

    func mintRouteSession() async throws -> RouteSessionStateDTO {
        mintRouteSessionCallCount += 1
        if let mintRouteSessionError {
            throw mintRouteSessionError
        }
        return routeSession(sessionID: "route_1", accessToken: "access_1", refreshOffset: 60, expiryOffset: 180)
    }

    func refreshRouteSession(sessionID _: String) async throws -> RouteSessionStateDTO {
        refreshRouteSessionCallCount += 1
        if let refreshRouteSessionError {
            throw refreshRouteSessionError
        }
        return routeSession(sessionID: "route_1", accessToken: "access_2", refreshOffset: 120, expiryOffset: 300)
    }

    func revokeRouteSession(sessionID _: String) async throws -> RouteSessionRevokeResponseDTO {
        revokeRouteSessionCallCount += 1
        return RouteSessionRevokeResponseDTO(session_id: "route_1", status: "revoked", revoked_at: now)
    }

    func createProtectedSession(url _: String) async throws -> ProtectedSessionStateDTO {
        fatalError("not used")
    }

    func makeProtectedSessionStreamRequest(sessionID _: String) throws -> URLRequest {
        fatalError("not used")
    }

    func getProtectedSessionState(sessionID _: String) async throws -> ProtectedSessionStateDTO {
        fatalError("not used")
    }

    func sendProtectedSessionAction(sessionID _: String, action _: ProtectedSessionActionRequestDTO) async throws -> ProtectedSessionStateDTO {
        fatalError("not used")
    }

    func endProtectedSession(sessionID _: String) async throws -> ProtectedSessionEndResponseDTO {
        fatalError("not used")
    }

    func compare(title _: String, items _: [Item]) async throws -> CompareResponseDTO {
        fatalError("not used")
    }

    func research(title _: String, promptContext _: String?, items _: [Item]) async throws -> ResearchResponseDTO {
        fatalError("not used")
    }

    func clearSession() throws {}

    private func routeSession(sessionID: String, accessToken: String, refreshOffset: TimeInterval, expiryOffset: TimeInterval) -> RouteSessionStateDTO {
        RouteSessionStateDTO(
            session_id: sessionID,
            access_token: accessToken,
            status: .active,
            route_kind: .localRouted,
            transport_kind: "packet_tunnel",
            control_plane_kind: "control_only",
            product_session_id: "product_1",
            auth_session_id: nil,
            issued_at: now,
            refresh_after: now.addingTimeInterval(refreshOffset),
            expires_at: now.addingTimeInterval(expiryOffset)
        )
    }
}
