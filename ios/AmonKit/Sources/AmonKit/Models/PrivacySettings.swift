import Combine
import Foundation

public enum PrivacyPreset: String, CaseIterable, Codable, Identifiable, Sendable {
    case balanced
    case privateMode = "private"
    case strict

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .balanced:
            return "Balanced"
        case .privateMode:
            return "Private"
        case .strict:
            return "Strict"
        }
    }

    public var summary: String {
        switch self {
        case .balanced:
            return "Best compatibility"
        case .privateMode:
            return "Less retained browsing state"
        case .strict:
            return "More isolation, fewer conveniences"
        }
    }
}

public enum DefaultBrowsingMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case standard
    case cleanView = "clean_view"
    case protectedSession = "protected_session"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .standard:
            return "Local"
        case .cleanView:
            return "Clean View"
        case .protectedSession:
            return "Protected Session"
        }
    }

    public var summary: String {
        switch self {
        case .standard:
            return "Render on-device through Amon's privacy route when available."
        case .cleanView:
            return "Amon fetches readable content on your behalf first."
        case .protectedSession:
            return "Amon opens supported sites in a remote ephemeral session."
        }
    }
}

public enum BrowsingSessionPersistence: String, CaseIterable, Codable, Identifiable, Sendable {
    case persistent
    case sessionOnly = "session_only"
    case ephemeral

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .persistent:
            return "Persistent"
        case .sessionOnly:
            return "Session Only"
        case .ephemeral:
            return "Ephemeral"
        }
    }

    public var summary: String {
        switch self {
        case .persistent:
            return "Website state is retained until you clear it."
        case .sessionOnly:
            return "Website state is cleared when the app session ends."
        case .ephemeral:
            return "New site opens use an isolated website store."
        }
    }
}

public struct BrowsingPrivacySettings: Codable, Equatable, Sendable {
    public var defaultBrowsingMode: DefaultBrowsingMode
    public var sessionPersistence: BrowsingSessionPersistence

    public init(
        defaultBrowsingMode: DefaultBrowsingMode,
        sessionPersistence: BrowsingSessionPersistence
    ) {
        self.defaultBrowsingMode = defaultBrowsingMode
        self.sessionPersistence = sessionPersistence
    }
}

public struct RetrievalPrivacySettings: Codable, Equatable, Sendable {
    public var useBackendReaderForDeeperModes: Bool
    public var saveRetrievedContentLocally: Bool

    public init(
        useBackendReaderForDeeperModes: Bool,
        saveRetrievedContentLocally: Bool
    ) {
        self.useBackendReaderForDeeperModes = useBackendReaderForDeeperModes
        self.saveRetrievedContentLocally = saveRetrievedContentLocally
    }
}

public struct WorkspacePrivacySettings: Codable, Equatable, Sendable {
    public var autoSaveSourcesForDeeperModes: Bool

    public init(autoSaveSourcesForDeeperModes: Bool) {
        self.autoSaveSourcesForDeeperModes = autoSaveSourcesForDeeperModes
    }
}

public struct PrivacySettings: Codable, Equatable, Sendable {
    public var browsing: BrowsingPrivacySettings
    public var retrieval: RetrievalPrivacySettings
    public var workspace: WorkspacePrivacySettings

    public init(
        browsing: BrowsingPrivacySettings,
        retrieval: RetrievalPrivacySettings,
        workspace: WorkspacePrivacySettings
    ) {
        self.browsing = browsing
        self.retrieval = retrieval
        self.workspace = workspace
    }

    public static let balanced = PrivacySettings(
        browsing: BrowsingPrivacySettings(
            defaultBrowsingMode: .standard,
            sessionPersistence: .persistent
        ),
        retrieval: RetrievalPrivacySettings(
            useBackendReaderForDeeperModes: false,
            saveRetrievedContentLocally: true
        ),
        workspace: WorkspacePrivacySettings(
            autoSaveSourcesForDeeperModes: true
        )
    )

    public static let `private` = PrivacySettings(
        browsing: BrowsingPrivacySettings(
            defaultBrowsingMode: .cleanView,
            sessionPersistence: .sessionOnly
        ),
        retrieval: RetrievalPrivacySettings(
            useBackendReaderForDeeperModes: true,
            saveRetrievedContentLocally: true
        ),
        workspace: WorkspacePrivacySettings(
            autoSaveSourcesForDeeperModes: true
        )
    )

    public static let strict = PrivacySettings(
        browsing: BrowsingPrivacySettings(
            defaultBrowsingMode: .cleanView,
            sessionPersistence: .ephemeral
        ),
        retrieval: RetrievalPrivacySettings(
            useBackendReaderForDeeperModes: true,
            saveRetrievedContentLocally: false
        ),
        workspace: WorkspacePrivacySettings(
            autoSaveSourcesForDeeperModes: false
        )
    )

    public static func forPreset(_ preset: PrivacyPreset) -> PrivacySettings {
        switch preset {
        case .balanced:
            return .balanced
        case .privateMode:
            return .private
        case .strict:
            return .strict
        }
    }

    public var matchingPreset: PrivacyPreset? {
        if self == .balanced {
            return .balanced
        }
        if self == .private {
            return .privateMode
        }
        if self == .strict {
            return .strict
        }
        return nil
    }
}

@MainActor
public final class PrivacySettingsStore: ObservableObject {
    @Published public private(set) var settings: PrivacySettings

    private let userDefaults: UserDefaults
    private let storageKey: String

    public init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = "amon.privacy.settings"
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey

        if let data = userDefaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder.amon.decode(PrivacySettings.self, from: data) {
            settings = decoded
        } else {
            settings = .balanced
        }
    }

    public var selectedPreset: PrivacyPreset? {
        settings.matchingPreset
    }

    public func applyPreset(_ preset: PrivacyPreset) {
        settings = PrivacySettings.forPreset(preset)
        persist()
    }

    public func updateBrowsingMode(_ mode: DefaultBrowsingMode) {
        settings.browsing.defaultBrowsingMode = mode
        persist()
    }

    public func updateSessionPersistence(_ persistence: BrowsingSessionPersistence) {
        settings.browsing.sessionPersistence = persistence
        persist()
    }

    public func updateUseBackendReaderForDeeperModes(_ isEnabled: Bool) {
        settings.retrieval.useBackendReaderForDeeperModes = isEnabled
        persist()
    }

    public func updateSaveRetrievedContentLocally(_ isEnabled: Bool) {
        settings.retrieval.saveRetrievedContentLocally = isEnabled
        persist()
    }

    public func updateAutoSaveSourcesForDeeperModes(_ isEnabled: Bool) {
        settings.workspace.autoSaveSourcesForDeeperModes = isEnabled
        persist()
    }

    public func reset() {
        settings = .balanced
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder.amon.encode(settings) else { return }
        userDefaults.set(data, forKey: storageKey)
    }
}
