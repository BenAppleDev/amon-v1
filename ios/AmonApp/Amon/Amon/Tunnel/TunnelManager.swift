import AmonKit
import Combine
import Foundation
import NetworkExtension

@MainActor
final class TunnelManager: ObservableObject {
    static let tunnelProviderBundleIdentifier = "com.benappledev.Amon.TunnelExtension"
    static let tunnelDisplayName = "Amon Tunnel"

    private enum ConfigurationKey {
        static let serverHost = "serverHost"
        static let serverPort = "serverPort"
        static let clientAddress = "clientAddress"
        static let subnetMask = "subnetMask"
        static let remoteAddress = "remoteAddress"
        static let dnsServers = "dnsServers"
        static let mtu = "mtu"
    }

    @Published private(set) var statusSnapshot: TransportTunnelStatusSnapshot = .disconnected

    private var manager: NETunnelProviderManager?
    private var statusObservation: NSObjectProtocol?

    deinit {
        if let statusObservation {
            NotificationCenter.default.removeObserver(statusObservation)
        }
    }

    func refreshFromPreferences(using settings: TransportPrivacySettings) async {
        do {
            manager = try await loadExistingManager()
            guard let manager else {
                statusSnapshot = .disconnected
                return
            }
            attachStatusObserver()
            updateStatusFromConnection(for: manager)
        } catch {
            statusSnapshot = TransportTunnelStatusSnapshot(
                state: .failed,
                detail: humanReadableMessage(for: error)
            )
        }
    }

    func connect(using settings: TransportPrivacySettings) async {
        guard settings.endpoint.isConfigured else {
            statusSnapshot = TransportTunnelStatusSnapshot(
                state: .failed,
                detail: "Set your laptop endpoint before connecting."
            )
            return
        }

        statusSnapshot = TransportTunnelStatusSnapshot(
            state: .connecting,
            detail: "Connecting to \(settings.endpoint.displayAddress)"
        )

        do {
            try validateProviderConfiguration()
            let manager = try await loadOrCreateManager()
            try await installConfigurationIfNeeded(using: settings)
            self.manager = manager
            attachStatusObserver()
            try manager.connection.startVPNTunnel()
            updateStatusFromConnection(for: manager)
        } catch {
            statusSnapshot = TransportTunnelStatusSnapshot(
                state: .failed,
                detail: humanReadableMessage(for: error)
            )
        }
    }

    func disconnect() {
        manager?.connection.stopVPNTunnel()
        updateStatusFromConnection()
    }

    private func attachStatusObserver() {
        guard let connection = manager?.connection else { return }

        if let statusObservation {
            NotificationCenter.default.removeObserver(statusObservation)
        }

        statusObservation = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: connection,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [self] in
                self.updateStatusFromConnection()
            }
        }
    }

    private func updateStatusFromConnection() {
        guard let manager else {
            statusSnapshot = .disconnected
            return
        }
        updateStatusFromConnection(for: manager)
    }

    private func updateStatusFromConnection(for manager: NETunnelProviderManager) {
        let endpointDetail = endpointSummary(from: manager)
        switch manager.connection.status {
        case .connected:
            statusSnapshot = TransportTunnelStatusSnapshot(
                state: .connected,
                detail: endpointDetail
            )
        case .connecting, .reasserting:
            statusSnapshot = TransportTunnelStatusSnapshot(
                state: .connecting,
                detail: endpointDetail
            )
        case .disconnecting:
            statusSnapshot = TransportTunnelStatusSnapshot(
                state: .disconnecting,
                detail: endpointDetail
            )
        case .disconnected, .invalid:
            statusSnapshot = TransportTunnelStatusSnapshot(
                state: .disconnected,
                detail: endpointDetail
            )
        @unknown default:
            statusSnapshot = TransportTunnelStatusSnapshot(
                state: .failed,
                detail: "Amon couldn't read the tunnel status."
            )
        }
    }

    private func loadExistingManager() async throws -> NETunnelProviderManager? {
        let existingManagers = try await loadAllManagers()
        return existingManagers.first(where: { existing in
            guard let protocolConfiguration = existing.protocolConfiguration as? NETunnelProviderProtocol else {
                return false
            }
            return protocolConfiguration.providerBundleIdentifier == Self.tunnelProviderBundleIdentifier
        })
    }

    private func loadOrCreateManager() async throws -> NETunnelProviderManager {
        if let manager {
            return manager
        }

        if let matched = try await loadExistingManager() {
            manager = matched
            return matched
        }

        let created = NETunnelProviderManager()
        created.localizedDescription = Self.tunnelDisplayName
        created.isEnabled = false
        manager = created
        return created
    }

    private func validateProviderConfiguration() throws {
        let pluginBundles = Bundle.main.builtInPlugInsURL
            .flatMap { try? FileManager.default.contentsOfDirectory(at: $0, includingPropertiesForKeys: nil) }
            ?? []

        let isProviderEmbedded = pluginBundles.contains { url in
            guard let bundle = Bundle(url: url) else { return false }
            return bundle.bundleIdentifier == Self.tunnelProviderBundleIdentifier
        }

        guard isProviderEmbedded else {
            throw TunnelConfigurationError.providerMissing
        }
    }

    private func installConfigurationIfNeeded(using settings: TransportPrivacySettings) async throws {
        guard let manager else { return }

        let protocolConfiguration = NETunnelProviderProtocol()
        protocolConfiguration.providerBundleIdentifier = Self.tunnelProviderBundleIdentifier
        protocolConfiguration.serverAddress = settings.endpoint.displayAddress
        protocolConfiguration.disconnectOnSleep = false
        protocolConfiguration.providerConfiguration = [
            ConfigurationKey.serverHost: settings.endpoint.serverHost,
            ConfigurationKey.serverPort: settings.endpoint.serverPort,
            ConfigurationKey.clientAddress: settings.endpoint.clientAddress,
            ConfigurationKey.subnetMask: settings.endpoint.subnetMask,
            ConfigurationKey.remoteAddress: settings.endpoint.remoteAddress,
            ConfigurationKey.dnsServers: settings.endpoint.dnsServers,
            ConfigurationKey.mtu: settings.endpoint.mtu,
        ]

        manager.localizedDescription = Self.tunnelDisplayName
        manager.protocolConfiguration = protocolConfiguration
        manager.isEnabled = settings.endpoint.isConfigured

        try await saveToPreferences(manager)
        try await loadFromPreferences(manager)
    }

    private func endpointSummary(from manager: NETunnelProviderManager) -> String? {
        (manager.protocolConfiguration as? NETunnelProviderProtocol)?.serverAddress
    }

    private func humanReadableMessage(for error: Error) -> String {
        if let tunnelError = error as? TunnelConfigurationError {
            return tunnelError.localizedDescription
        }

        if let configurationError = error as? NEVPNError {
            switch configurationError.code {
            case .configurationInvalid:
                return "The tunnel configuration is incomplete or invalid."
            case .configurationDisabled:
                return "The Amon tunnel is disabled in system preferences."
            case .connectionFailed:
                return "Amon couldn't reach the tunnel endpoint."
            case .configurationStale:
                return "The tunnel configuration changed underneath the app. Try again."
            case .configurationReadWriteFailed:
                return "This signed build could not save the tunnel configuration. Enable the Network Extension capability for both targets and install a build signed with a provisioning profile that includes packet-tunnel permission."
            case .configurationUnknown:
                return "The device rejected the current tunnel configuration."
            @unknown default:
                return configurationError.localizedDescription
            }
        }

        let nsError = error as NSError
        if (nsError.domain == "NEConfigurationErrorDomain" && nsError.code == 10)
            || (nsError.domain == "NEVPNErrorDomain" && nsError.code == 5) {
            return "This signed build does not currently have permission to install the Amon tunnel. Make sure the app and extension both have the Network Extension capability, then install a build signed with a provisioning profile that includes packet-tunnel permission."
        }

        return error.localizedDescription
    }
}

private enum TunnelConfigurationError: LocalizedError {
    case providerMissing

    var errorDescription: String? {
        switch self {
        case .providerMissing:
            return "The Amon Tunnel extension is not embedded in this build. Rebuild the app with the Packet Tunnel extension target included."
        }
    }
}

private func loadAllManagers() async throws -> [NETunnelProviderManager] {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[NETunnelProviderManager], Error>) in
        NETunnelProviderManager.loadAllFromPreferences { managers, error in
            if let error {
                continuation.resume(throwing: error)
            } else {
                continuation.resume(returning: managers ?? [])
            }
        }
    }
}

private func saveToPreferences(_ manager: NETunnelProviderManager) async throws {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
        manager.saveToPreferences { error in
            if let error {
                continuation.resume(throwing: error)
            } else {
                continuation.resume(returning: ())
            }
        }
    }
}

private func loadFromPreferences(_ manager: NETunnelProviderManager) async throws {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
        manager.loadFromPreferences { error in
            if let error {
                continuation.resume(throwing: error)
            } else {
                continuation.resume(returning: ())
            }
        }
    }
}
