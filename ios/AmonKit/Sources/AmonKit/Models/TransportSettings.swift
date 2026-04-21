import Foundation

public enum TransportTunnelStatusState: String, Equatable, Sendable {
    case connected
    case connecting
    case disconnected
    case disconnecting
    case failed

    public var title: String {
        switch self {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting"
        case .disconnected:
            return "Disconnected"
        case .disconnecting:
            return "Disconnecting"
        case .failed:
            return "Couldn't connect"
        }
    }

    public var summary: String {
        switch self {
        case .connected:
            return "Traffic can route through your Amon endpoint."
        case .connecting:
            return "Amon is establishing the tunnel."
        case .disconnected:
            return "Browsing leaves the device directly."
        case .disconnecting:
            return "Amon is closing the current tunnel session."
        case .failed:
            return "Amon could not establish the tunnel."
        }
    }
}

public struct TransportTunnelStatusSnapshot: Equatable, Hashable, Sendable {
    public var state: TransportTunnelStatusState
    public var detail: String?
    public var lastUpdatedAt: Date

    public init(
        state: TransportTunnelStatusState,
        detail: String? = nil,
        lastUpdatedAt: Date = Date()
    ) {
        self.state = state
        self.detail = detail
        self.lastUpdatedAt = lastUpdatedAt
    }

    public static let disconnected = TransportTunnelStatusSnapshot(state: .disconnected)
}

public struct TransportTunnelEndpointSettings: Codable, Equatable, Sendable {
    public var serverHost: String
    public var serverPort: Int
    public var clientAddress: String
    public var subnetMask: String
    public var remoteAddress: String
    public var dnsServers: [String]
    public var mtu: Int

    public init(
        serverHost: String = "",
        serverPort: Int = 9443,
        clientAddress: String = "10.44.0.2",
        subnetMask: String = "255.255.255.0",
        remoteAddress: String = "10.44.0.1",
        dnsServers: [String] = ["1.1.1.1", "1.0.0.1"],
        mtu: Int = 1280
    ) {
        self.serverHost = serverHost
        self.serverPort = serverPort
        self.clientAddress = clientAddress
        self.subnetMask = subnetMask
        self.remoteAddress = remoteAddress
        self.dnsServers = dnsServers
        self.mtu = mtu
    }

    public var isConfigured: Bool {
        !serverHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var displayAddress: String {
        guard isConfigured else { return "Set your laptop IP" }
        return "\(serverHost):\(serverPort)"
    }
}

public struct TransportPrivacySettings: Codable, Equatable, Sendable {
    public var enabledWhenSignedIn: Bool
    public var autoConnectOnSessionRestore: Bool
    public var endpoint: TransportTunnelEndpointSettings

    public init(
        enabledWhenSignedIn: Bool = false,
        autoConnectOnSessionRestore: Bool = true,
        endpoint: TransportTunnelEndpointSettings = .init()
    ) {
        self.enabledWhenSignedIn = enabledWhenSignedIn
        self.autoConnectOnSessionRestore = autoConnectOnSessionRestore
        self.endpoint = endpoint
    }
}

@MainActor
public final class TransportPrivacySettingsStore: ObservableObject {
    @Published public private(set) var settings: TransportPrivacySettings

    private let userDefaults: UserDefaults
    private let storageKey: String

    public init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = "amon.transport.settings"
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey

        if let data = userDefaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder.amon.decode(TransportPrivacySettings.self, from: data) {
            settings = decoded
        } else {
            settings = .init()
        }
    }

    public func updateEnabledWhenSignedIn(_ isEnabled: Bool) {
        settings.enabledWhenSignedIn = isEnabled
        persist()
    }

    public func updateAutoConnectOnSessionRestore(_ isEnabled: Bool) {
        settings.autoConnectOnSessionRestore = isEnabled
        persist()
    }

    public func updateEndpointHost(_ host: String) {
        settings.endpoint.serverHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        persist()
    }

    public func updateEndpointPort(_ port: Int) {
        settings.endpoint.serverPort = min(max(port, 1), 65535)
        persist()
    }

    public func updateClientAddress(_ value: String) {
        settings.endpoint.clientAddress = value.trimmingCharacters(in: .whitespacesAndNewlines)
        persist()
    }

    public func updateSubnetMask(_ value: String) {
        settings.endpoint.subnetMask = value.trimmingCharacters(in: .whitespacesAndNewlines)
        persist()
    }

    public func updateRemoteAddress(_ value: String) {
        settings.endpoint.remoteAddress = value.trimmingCharacters(in: .whitespacesAndNewlines)
        persist()
    }

    public func updateDNSServers(_ value: String) {
        settings.endpoint.dnsServers = value
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        persist()
    }

    public func updateMTU(_ value: Int) {
        settings.endpoint.mtu = min(max(value, 576), 1500)
        persist()
    }

    public func reset() {
        settings = .init()
        persist()
    }

    public var dnsServersDisplayValue: String {
        settings.endpoint.dnsServers.joined(separator: ", ")
    }

    private func persist() {
        guard let data = try? JSONEncoder.amon.encode(settings) else { return }
        userDefaults.set(data, forKey: storageKey)
    }
}
