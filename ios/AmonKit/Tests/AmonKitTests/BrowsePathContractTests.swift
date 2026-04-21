import XCTest
@testable import AmonKit

final class BrowsePathContractTests: XCTestCase {
    func testResolverKeepsLocalRoutedWhenCapabilityIsConnected() {
        let resolution = BrowsePathResolver.resolve(
            requestedPath: .localRouted,
            localRouteCapability: LocalRouteCapabilitySnapshot(
                state: .connected,
                readinessState: .relayAuthAccepted,
                detail: "Connected",
                routeSessionStatus: .active,
                routeSessionID: "route_1",
                relayStatus: LocalRouteRelayStatusSnapshot(state: .accepted),
                tunnelStatus: TransportTunnelStatusSnapshot(state: .connected)
            )
        )

        XCTAssertEqual(resolution.effectivePath, .localRouted)
        XCTAssertEqual(resolution.localRouteState, .connected)
        XCTAssertEqual(resolution.localRouteReadinessState, .relayAuthAccepted)
        XCTAssertNil(resolution.fallbackReason)
    }

    func testResolverDegradesToDirectFallbackWhenCapabilityIsDisconnected() {
        let resolution = BrowsePathResolver.resolve(
            requestedPath: .localRouted,
            localRouteCapability: LocalRouteCapabilitySnapshot(
                state: .disconnected,
                readinessState: .routeSessionAcquired,
                reason: .tunnelDisconnected,
                detail: "Amon has a routed-local session, but the tunnel is not connected.",
                routeSessionStatus: .active,
                routeSessionID: "route_1",
                relayStatus: .notStarted,
                tunnelStatus: .disconnected
            )
        )

        XCTAssertEqual(resolution.effectivePath, .directFallback)
        XCTAssertEqual(resolution.localRouteState, .disconnected)
        XCTAssertEqual(resolution.localRouteReason, .tunnelDisconnected)
        XCTAssertEqual(
            resolution.fallbackReason,
            "Amon has a routed-local session, but the tunnel is not connected."
        )
    }

    func testResolverDegradesToDirectFallbackWhenRelayAuthenticationWasRejected() {
        let resolution = BrowsePathResolver.resolve(
            requestedPath: .localRouted,
            localRouteCapability: LocalRouteCapabilitySnapshot(
                state: .degraded,
                readinessState: .relayAuthRejected,
                reason: .routeSessionExpired,
                detail: "The relay rejected the routed-local session because it expired.",
                routeSessionStatus: .active,
                routeSessionID: "route_1",
                relayStatus: LocalRouteRelayStatusSnapshot(
                    state: .rejected,
                    code: "route_session_expired",
                    detail: "The relay rejected the routed-local session because it expired."
                ),
                tunnelStatus: TransportTunnelStatusSnapshot(state: .connected)
            )
        )

        XCTAssertEqual(resolution.effectivePath, .directFallback)
        XCTAssertEqual(resolution.localRouteReadinessState, .relayAuthRejected)
        XCTAssertEqual(resolution.localRouteReason, .routeSessionExpired)
        XCTAssertEqual(
            resolution.fallbackReason,
            "The relay rejected the routed-local session because it expired."
        )
    }
}
