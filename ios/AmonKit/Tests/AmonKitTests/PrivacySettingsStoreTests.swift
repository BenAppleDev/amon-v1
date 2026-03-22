import XCTest
@testable import AmonKit

@MainActor
final class PrivacySettingsStoreTests: XCTestCase {
    func testDefaultsToBalancedPreset() {
        let store = makeStore()

        XCTAssertEqual(store.settings, .balanced)
        XCTAssertEqual(store.selectedPreset, .balanced)
    }

    func testApplyingPresetUpdatesUnderlyingSettings() {
        let store = makeStore()

        store.applyPreset(.strict)

        XCTAssertEqual(store.settings, .strict)
        XCTAssertEqual(store.selectedPreset, .strict)
        XCTAssertEqual(store.settings.browsing.defaultBrowsingMode, .cleanView)
        XCTAssertEqual(store.settings.browsing.sessionPersistence, .ephemeral)
        XCTAssertFalse(store.settings.retrieval.saveRetrievedContentLocally)
        XCTAssertFalse(store.settings.workspace.autoSaveSourcesForDeeperModes)
    }

    func testAdvancedEditMovesStoreIntoCustomState() {
        let store = makeStore()

        store.applyPreset(.balanced)
        store.updateSessionPersistence(.sessionOnly)

        XCTAssertNil(store.selectedPreset)
    }

    func testSettingsPersistAcrossStoreInstances() {
        let suiteName = "amon.tests.privacy.persistence.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let first = PrivacySettingsStore(userDefaults: defaults, storageKey: "privacy")
        first.applyPreset(.privateMode)

        let second = PrivacySettingsStore(userDefaults: defaults, storageKey: "privacy")

        XCTAssertEqual(second.settings, .private)
        XCTAssertEqual(second.selectedPreset, .privateMode)
    }

    private func makeStore() -> PrivacySettingsStore {
        let suiteName = "amon.tests.privacy.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return PrivacySettingsStore(userDefaults: defaults, storageKey: "privacy")
    }
}
