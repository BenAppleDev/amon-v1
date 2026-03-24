import XCTest
@testable import AmonKit

@MainActor
final class TransportPrivacySettingsStoreTests: XCTestCase {
    func testDefaultsToDisabledTunnelWithDevEndpointShape() {
        let store = makeStore()

        XCTAssertFalse(store.settings.enabledWhenSignedIn)
        XCTAssertTrue(store.settings.autoConnectOnSessionRestore)
        XCTAssertEqual(store.settings.endpoint.serverPort, 9443)
        XCTAssertEqual(store.settings.endpoint.clientAddress, "10.44.0.2")
        XCTAssertEqual(store.settings.endpoint.remoteAddress, "10.44.0.1")
    }

    func testSettingsPersistAcrossStoreInstances() {
        let suiteName = "amon.tests.transport.persistence.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let first = TransportPrivacySettingsStore(userDefaults: defaults, storageKey: "transport")
        first.updateEnabledWhenSignedIn(true)
        first.updateAutoConnectOnSessionRestore(false)
        first.updateEndpointHost("192.168.1.25")
        first.updateEndpointPort(10443)
        first.updateDNSServers("9.9.9.9, 1.1.1.1")

        let second = TransportPrivacySettingsStore(userDefaults: defaults, storageKey: "transport")

        XCTAssertTrue(second.settings.enabledWhenSignedIn)
        XCTAssertFalse(second.settings.autoConnectOnSessionRestore)
        XCTAssertEqual(second.settings.endpoint.serverHost, "192.168.1.25")
        XCTAssertEqual(second.settings.endpoint.serverPort, 10443)
        XCTAssertEqual(second.settings.endpoint.dnsServers, ["9.9.9.9", "1.1.1.1"])
    }

    func testNumericAndDNSInputsAreNormalized() {
        let store = makeStore()

        store.updateEndpointPort(70000)
        store.updateMTU(120)
        store.updateDNSServers(" 1.1.1.1 , , 8.8.8.8 ")

        XCTAssertEqual(store.settings.endpoint.serverPort, 65535)
        XCTAssertEqual(store.settings.endpoint.mtu, 576)
        XCTAssertEqual(store.settings.endpoint.dnsServers, ["1.1.1.1", "8.8.8.8"])
    }

    private func makeStore() -> TransportPrivacySettingsStore {
        let suiteName = "amon.tests.transport.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return TransportPrivacySettingsStore(userDefaults: defaults, storageKey: "transport")
    }
}
