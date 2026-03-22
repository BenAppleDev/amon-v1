import Foundation
import WebKit

public enum BrowserPrivacyController {
    public static func websiteDataStore(for persistence: BrowsingSessionPersistence) -> WKWebsiteDataStore {
        switch persistence {
        case .persistent, .sessionOnly:
            return .default()
        case .ephemeral:
            return .nonPersistent()
        }
    }

    @MainActor
    public static func clearWebsiteData() async {
        URLCache.shared.removeAllCachedResponses()
        HTTPCookieStorage.shared.removeCookies(since: .distantPast)

        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        let startDate = Date(timeIntervalSince1970: 0)
        await withCheckedContinuation { continuation in
            WKWebsiteDataStore.default().removeData(ofTypes: dataTypes, modifiedSince: startDate) {
                continuation.resume()
            }
        }
    }

    @MainActor
    public static func clearWebsiteDataIfNeededOnLaunch(using settings: PrivacySettings) async {
        if settings.browsing.sessionPersistence != .persistent {
            await clearWebsiteData()
        }
    }

    @MainActor
    public static func clearWebsiteDataIfNeededOnBackground(using settings: PrivacySettings) async {
        if settings.browsing.sessionPersistence == .sessionOnly {
            await clearWebsiteData()
        }
    }
}
