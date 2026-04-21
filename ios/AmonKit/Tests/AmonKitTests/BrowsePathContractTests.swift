import XCTest
@testable import AmonKit

final class BrowsePathContractTests: XCTestCase {
    func testResolverKeepsLocalRoutedWhenCapabilityIsConnected() {
        let resolution = BrowsePathResolver.resolve(
            requestedPath: .localRouted,
            localRouteCapability: LocalRouteCapabilitySnapshot(
                state: .connected,
                detail: "Connected",
                routeSessionStatus: .active,
                routeSessionID: "route_1",
                tunnelStatus: TransportTunnelStatusSnapshot(state: .connected)
            )
        )

        XCTAssertEqual(resolution.effectivePath, .localRouted)
        XCTAssertEqual(resolution.localRouteState, .connected)
        XCTAssertNil(resolution.fallbackReason)
    }

    func testResolverDegradesToDirectFallbackWhenCapabilityIsDisconnected() {
        let resolution = BrowsePathResolver.resolve(
            requestedPath: .localRouted,
            localRouteCapability: LocalRouteCapabilitySnapshot(
                state: .disconnected,
                reason: .tunnelDisconnected,
                detail: "Amon has a routed-local session, but the tunnel is not connected.",
                routeSessionStatus: .active,
                routeSessionID: "route_1",
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
}
