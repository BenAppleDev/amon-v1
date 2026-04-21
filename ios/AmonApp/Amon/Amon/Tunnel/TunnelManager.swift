import AmonKit
import Combine
import Foundation
import NetworkExtension
import OSLog

@MainActor
final class TunnelManager: ObservableObject {
    static let fallbackTunnelProviderBundleIdentifier = "com.benappledev.Amon.TunnelExtension"
    static let tunnelDisplayName = "Amon Tunnel"
    private static let logger = Logger(subsystem: "com.benappledev.Amon", category: "TunnelManager")
    private static let startTransitionPollCount = 12
    private static let startTransitionPollDelayNanoseconds: UInt64 = 500_000_000

    private enum ConfigurationKey {
        static let serverHost = "serverHost"
        static let serverPort = "serverPort"
        static let clientAddress = "clientAddress"
        static let subnetMask = "subnetMask"
        static let remoteAddress = "remoteAddress"
        static let dnsServers = "dnsServers"
        static let mtu = "mtu"
        static let routeSessionID = "routeSessionID"
        static let routeAccessToken = "routeAccessToken"
        static let routeExpiresAt = "routeExpiresAt"
        static let routeAuthSessionID = "routeAuthSessionID"
    }

    private enum StartOptionKey {
        static let requestedAt = "requestedAt"
        static let requestedHost = "requestedHost"
        static let requestedPort = "requestedPort"
        static let providerBundleIdentifier = "providerBundleIdentifier"
    }

    private enum ProviderMessageKey {
        static let routeBootstrapStatus = "route_bootstrap_status"
    }

    @Published private(set) var statusSnapshot: TransportTunnelStatusSnapshot = .disconnected
    @Published private(set) var routeRelayStatus: LocalRouteRelayStatusSnapshot = .notStarted
    @Published private(set) var diagnostics: [String] = []

    private var manager: NETunnelProviderManager?
    private var statusObservation: NSObjectProtocol?
    private var resolvedProviderBundleIdentifier: String?

    deinit {
        if let statusObservation {
            NotificationCenter.default.removeObserver(statusObservation)
        }
    }

    func refreshFromPreferences(using settings: TransportPrivacySettings) async {
        log("Refresh requested with settings \(configurationSummary(for: settings))")

        resolvedProviderBundleIdentifier = resolveProviderBundleIdentifier()
        log("Using provider bundle identifier \(providerBundleIdentifier)")

        do {
            manager = try await loadExistingManager()
            guard let manager else {
                log("No saved tunnel manager found")
                statusSnapshot = .disconnected
                routeRelayStatus = .notStarted
                return
            }

            log("Loaded saved manager with status \(describe(manager.connection.status)) and config \(configurationSummary(from: manager))")
            attachStatusObserver()
            updateStatusFromConnection(for: manager)
            await refreshRouteRelayStatus(for: manager)
        } catch {
            log("Refresh failed: \(errorDescription(for: error))", level: .error)
            statusSnapshot = TransportTunnelStatusSnapshot(
                state: .failed,
                detail: humanReadableMessage(for: error)
            )
            routeRelayStatus = LocalRouteRelayStatusSnapshot(
                state: .unavailable,
                code: "relay_status_refresh_failed",
                detail: humanReadableMessage(for: error)
            )
        }
    }

    func connect(using settings: TransportPrivacySettings, routeSession: RouteSessionStateDTO?) async {
        log("Connect requested with settings \(configurationSummary(for: settings))")

        guard settings.endpoint.isConfigured else {
            log("Connect rejected because the laptop endpoint is not configured", level: .error)
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
        routeRelayStatus = LocalRouteRelayStatusSnapshot(
            state: .pending,
            detail: "Amon is authenticating the routed-local tunnel with the relay."
        )

        resolvedProviderBundleIdentifier = resolveProviderBundleIdentifier()
        log("Using provider bundle identifier \(providerBundleIdentifier)")

        do {
            try validateSettings(settings)
            try validateRouteSession(routeSession)
            try validateProviderConfiguration()

            let manager = try await loadOrCreateManager()
            log("Using tunnel manager object \(String(describing: ObjectIdentifier(manager)))")

            try await installConfigurationIfNeeded(using: settings, routeSession: routeSession, on: manager)
            self.manager = manager
            attachStatusObserver()

            let startOptions = makeStartOptions(from: settings, routeSession: routeSession)
            if let session = manager.connection as? NETunnelProviderSession {
                log("Starting NETunnelProviderSession with options \(startOptions)")
                try session.startTunnel(options: startOptions)
                log("NETunnelProviderSession.startTunnel returned without throwing; immediate status \(describe(manager.connection.status))")
            } else {
                log("Tunnel connection is \(String(describing: type(of: manager.connection))); falling back to startVPNTunnel()", level: .error)
                try manager.connection.startVPNTunnel()
                log("startVPNTunnel returned without throwing; immediate status \(describe(manager.connection.status))")
            }

            updateStatusFromConnection(for: manager)
            await monitorStartTransition(for: manager)
            await refreshRouteRelayStatus(for: manager)
        } catch {
            log("Connect failed: \(errorDescription(for: error))", level: .error)
            statusSnapshot = TransportTunnelStatusSnapshot(
                state: .failed,
                detail: humanReadableMessage(for: error)
            )
            routeRelayStatus = parsedRouteRelayStatus(from: error)
                ?? LocalRouteRelayStatusSnapshot(
                    state: .unavailable,
                    code: "relay_connect_failed",
                    detail: humanReadableMessage(for: error)
                )
        }
    }

    func disconnect() {
        log("Disconnect requested")
        manager?.connection.stopVPNTunnel()
        routeRelayStatus = .notStarted
        updateStatusFromConnection()
    }

    func recordExternalEvent(_ message: String) {
        log(message)
    }

    private func attachStatusObserver() {
        guard let connection = manager?.connection else {
            log("Status observer not attached because manager connection is missing", level: .error)
            return
        }

        if let statusObservation {
            NotificationCenter.default.removeObserver(statusObservation)
        }

        log("Attaching NEVPNStatusDidChange observer")
        statusObservation = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: connection,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.log("Observed NEVPNStatusDidChange notification")
                self.updateStatusFromConnection()
                await self.refreshRouteRelayStatusFromCurrentManager()
            }
        }
    }

    private func updateStatusFromConnection() {
        guard let manager else {
            log("No active manager; reporting disconnected")
            statusSnapshot = .disconnected
            return
        }
        updateStatusFromConnection(for: manager)
    }

    private func updateStatusFromConnection(for manager: NETunnelProviderManager) {
        let endpointDetail = endpointSummary(from: manager)
        log("Connection status is now \(describe(manager.connection.status)) (enabled=\(manager.isEnabled), endpoint=\(endpointDetail ?? "none"))")

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
        log("Loading tunnel managers from system preferences")
        let existingManagers = try await loadAllManagers()
        log("System returned \(existingManagers.count) tunnel manager(s)")

        for (index, existing) in existingManagers.enumerated() {
            let summary = configurationSummary(from: existing)
            log("Manager[\(index)] \(summary)")
        }

        return existingManagers.first(where: { existing in
            guard let protocolConfiguration = existing.protocolConfiguration as? NETunnelProviderProtocol else {
                return false
            }
            return protocolConfiguration.providerBundleIdentifier == providerBundleIdentifier
        })
    }

    private func loadOrCreateManager() async throws -> NETunnelProviderManager {
        if let manager {
            log("Reusing cached tunnel manager")
            return manager
        }

        if let matched = try await loadExistingManager() {
            log("Reusing existing persisted tunnel manager")
            manager = matched
            return matched
        }

        let created = NETunnelProviderManager()
        created.localizedDescription = Self.tunnelDisplayName
        created.isEnabled = false
        log("Created new NETunnelProviderManager")
        manager = created
        return created
    }

    private func validateSettings(_ settings: TransportPrivacySettings) throws {
        let host = settings.endpoint.serverHost.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedHost = host.lowercased()
        guard !host.isEmpty else {
            throw TunnelConfigurationError.invalidEndpointHost("Set your laptop host or IP before connecting.")
        }

        guard !host.contains("://") else {
            throw TunnelConfigurationError.invalidEndpointHost("Use only the laptop host or IP address. Leave out http:// or https://.")
        }

        guard !["localhost", "127.0.0.1", "::1", "0.0.0.0"].contains(normalizedHost) else {
            throw TunnelConfigurationError.invalidEndpointHost("Use your laptop's LAN IP address here, not localhost or 0.0.0.0.")
        }

        guard (1...65535).contains(settings.endpoint.serverPort) else {
            throw TunnelConfigurationError.invalidPort
        }
    }

    private func validateProviderConfiguration() throws {
        let bundles = embeddedPluginBundles()
        let bundleDescriptions = bundles.map { bundle in
            "\(bundle.bundleIdentifier ?? "<nil>")@\(bundle.bundleURL.lastPathComponent)"
        }.joined(separator: ", ")
        log("Embedded plugin bundles: \(bundleDescriptions.isEmpty ? "<none>" : bundleDescriptions)")

        let isProviderEmbedded = bundles.contains { bundle in
            bundle.bundleIdentifier == providerBundleIdentifier
        }

        guard isProviderEmbedded else {
            throw TunnelConfigurationError.providerMissing(expectedBundleIdentifier: providerBundleIdentifier)
        }
    }

    private func validateRouteSession(_ routeSession: RouteSessionStateDTO?) throws {
        guard let routeSession else {
            throw TunnelConfigurationError.routeSessionMissing
        }
        guard routeSession.status == .active else {
            throw TunnelConfigurationError.routeSessionInactive
        }
        guard routeSession.route_kind == .localRouted else {
            throw TunnelConfigurationError.routeSessionInactive
        }
        guard routeSession.expires_at > Date() else {
            throw TunnelConfigurationError.routeSessionExpired
        }
    }

    private func embeddedPluginBundles() -> [Bundle] {
        let pluginURLs = Bundle.main.builtInPlugInsURL
            .flatMap { try? FileManager.default.contentsOfDirectory(at: $0, includingPropertiesForKeys: nil) }
            ?? []
        return pluginURLs.compactMap(Bundle.init(url:))
    }

    private func resolveProviderBundleIdentifier() -> String {
        if let resolvedProviderBundleIdentifier {
            return resolvedProviderBundleIdentifier
        }

        let packetTunnelBundle = embeddedPluginBundles().first(where: { bundle in
            guard let extensionAttributes = bundle.infoDictionary?["NSExtension"] as? [String: Any] else {
                return false
            }
            let extensionPoint = extensionAttributes["NSExtensionPointIdentifier"] as? String
            return extensionPoint == "com.apple.networkextension.packet-tunnel"
        })

        if let bundleIdentifier = packetTunnelBundle?.bundleIdentifier, !bundleIdentifier.isEmpty {
            resolvedProviderBundleIdentifier = bundleIdentifier
            log("Resolved packet tunnel provider bundle identifier \(bundleIdentifier) from embedded extension")
            return bundleIdentifier
        }

        resolvedProviderBundleIdentifier = Self.fallbackTunnelProviderBundleIdentifier
        log("Falling back to hardcoded provider bundle identifier \(Self.fallbackTunnelProviderBundleIdentifier)")
        return Self.fallbackTunnelProviderBundleIdentifier
    }

    private var providerBundleIdentifier: String {
        resolvedProviderBundleIdentifier ?? Self.fallbackTunnelProviderBundleIdentifier
    }

    private func installConfigurationIfNeeded(
        using settings: TransportPrivacySettings,
        routeSession: RouteSessionStateDTO?,
        on manager: NETunnelProviderManager
    ) async throws {
        if configurationMatchesExistingManager(manager, settings: settings, routeSession: routeSession) {
            log("Persisted tunnel configuration already matches the requested endpoint; skipping save")
            return
        }

        guard let routeSession else {
            throw TunnelConfigurationError.routeSessionMissing
        }

        let providerConfiguration: [String: Any] = [
            ConfigurationKey.serverHost: settings.endpoint.serverHost,
            ConfigurationKey.serverPort: settings.endpoint.serverPort,
            ConfigurationKey.clientAddress: settings.endpoint.clientAddress,
            ConfigurationKey.subnetMask: settings.endpoint.subnetMask,
            ConfigurationKey.remoteAddress: settings.endpoint.remoteAddress,
            ConfigurationKey.dnsServers: settings.endpoint.dnsServers,
            ConfigurationKey.mtu: settings.endpoint.mtu,
            ConfigurationKey.routeSessionID: routeSession.session_id,
            ConfigurationKey.routeAccessToken: routeSession.access_token,
            ConfigurationKey.routeExpiresAt: ISO8601DateFormatter().string(from: routeSession.expires_at),
            ConfigurationKey.routeAuthSessionID: routeSession.auth_session_id,
        ]

        let protocolConfiguration = NETunnelProviderProtocol()
        protocolConfiguration.providerBundleIdentifier = providerBundleIdentifier
        protocolConfiguration.serverAddress = settings.endpoint.displayAddress
        protocolConfiguration.disconnectOnSleep = false
        protocolConfiguration.providerConfiguration = providerConfiguration

        manager.localizedDescription = Self.tunnelDisplayName
        manager.protocolConfiguration = protocolConfiguration
        manager.isEnabled = settings.endpoint.isConfigured

        log("Installing protocol configuration \(configurationSummary(for: settings))")
        log("Saving tunnel configuration to system preferences")
        try await saveToPreferences(manager)
        log("Tunnel configuration saved successfully")

        log("Reloading tunnel configuration from system preferences")
        try await loadFromPreferences(manager)
        log("Reloaded tunnel configuration successfully: \(configurationSummary(from: manager))")
    }

    private func configurationMatchesExistingManager(
        _ manager: NETunnelProviderManager,
        settings: TransportPrivacySettings,
        routeSession: RouteSessionStateDTO?
    ) -> Bool {
        guard let configuration = manager.protocolConfiguration as? NETunnelProviderProtocol else {
            return false
        }

        let providerConfiguration = configuration.providerConfiguration ?? [:]
        let storedHost = providerConfiguration[ConfigurationKey.serverHost] as? String
        let storedPort = intValue(providerConfiguration[ConfigurationKey.serverPort])
        let storedClient = providerConfiguration[ConfigurationKey.clientAddress] as? String
        let storedSubnetMask = providerConfiguration[ConfigurationKey.subnetMask] as? String
        let storedRemote = providerConfiguration[ConfigurationKey.remoteAddress] as? String
        let storedMTU = intValue(providerConfiguration[ConfigurationKey.mtu])
        let storedDNS = stringArrayValue(providerConfiguration[ConfigurationKey.dnsServers])
        let storedRouteSessionID = providerConfiguration[ConfigurationKey.routeSessionID] as? String
        let storedRouteExpiresAt = providerConfiguration[ConfigurationKey.routeExpiresAt] as? String
        let storedRouteAuthSessionID = providerConfiguration[ConfigurationKey.routeAuthSessionID] as? String

        let endpoint = settings.endpoint
        return configuration.providerBundleIdentifier == providerBundleIdentifier
            && configuration.serverAddress == endpoint.displayAddress
            && manager.isEnabled == endpoint.isConfigured
            && storedHost == endpoint.serverHost
            && storedPort == endpoint.serverPort
            && storedClient == endpoint.clientAddress
            && storedSubnetMask == endpoint.subnetMask
            && storedRemote == endpoint.remoteAddress
            && storedMTU == endpoint.mtu
            && storedDNS == endpoint.dnsServers
            && storedRouteSessionID == routeSession?.session_id
            && storedRouteExpiresAt == routeSession.map { ISO8601DateFormatter().string(from: $0.expires_at) }
            && storedRouteAuthSessionID == routeSession?.auth_session_id
    }

    private func endpointSummary(from manager: NETunnelProviderManager) -> String? {
        (manager.protocolConfiguration as? NETunnelProviderProtocol)?.serverAddress
    }

    private func refreshRouteRelayStatusFromCurrentManager() async {
        guard let manager else {
            routeRelayStatus = .notStarted
            return
        }
        await refreshRouteRelayStatus(for: manager)
    }

    private func refreshRouteRelayStatus(for manager: NETunnelProviderManager) async {
        switch manager.connection.status {
        case .connected:
            routeRelayStatus = await queryRouteRelayStatusFromProvider(for: manager)
        case .connecting, .reasserting:
            if routeRelayStatus.state != .accepted {
                routeRelayStatus = LocalRouteRelayStatusSnapshot(
                    state: .pending,
                    detail: "Amon is authenticating the routed-local tunnel with the relay."
                )
            }
        case .disconnecting:
            routeRelayStatus = LocalRouteRelayStatusSnapshot(
                state: .unavailable,
                code: "relay_disconnect_in_progress",
                detail: "The routed-local tunnel is disconnecting."
            )
        case .disconnected, .invalid:
            if let disconnectError = await fetchLastDisconnectError(for: manager.connection),
               let parsedStatus = parsedRouteRelayStatus(from: disconnectError) {
                routeRelayStatus = parsedStatus
            } else {
                routeRelayStatus = .notStarted
            }
        @unknown default:
            routeRelayStatus = LocalRouteRelayStatusSnapshot(
                state: .unavailable,
                code: "relay_status_unknown",
                detail: "Amon couldn't determine the routed-local relay auth state."
            )
        }
    }

    private func queryRouteRelayStatusFromProvider(for manager: NETunnelProviderManager) async -> LocalRouteRelayStatusSnapshot {
        guard let session = manager.connection as? NETunnelProviderSession else {
            return LocalRouteRelayStatusSnapshot(
                state: .unavailable,
                code: "relay_status_unavailable",
                detail: "Amon couldn't talk to the tunnel provider session."
            )
        }

        do {
            let responseData = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data?, Error>) in
                do {
                    try session.sendProviderMessage(Data(ProviderMessageKey.routeBootstrapStatus.utf8)) { responseData in
                        continuation.resume(returning: responseData)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            guard let responseData else {
                return LocalRouteRelayStatusSnapshot(
                    state: .unavailable,
                    code: "relay_status_empty",
                    detail: "The tunnel provider did not return a routed-local relay status."
                )
            }

            let response = try JSONDecoder().decode(RouteRelayStatusResponse.self, from: responseData)
            return response.snapshot
        } catch {
            return parsedRouteRelayStatus(from: error)
                ?? LocalRouteRelayStatusSnapshot(
                    state: .unavailable,
                    code: "relay_status_query_failed",
                    detail: humanReadableMessage(for: error)
                )
        }
    }

    private func fetchLastDisconnectError(for connection: NEVPNConnection) async -> Error? {
        await withCheckedContinuation { continuation in
            connection.fetchLastDisconnectError { error in
                continuation.resume(returning: error)
            }
        }
    }

    private func parsedRouteRelayStatus(from error: Error) -> LocalRouteRelayStatusSnapshot? {
        let rawMessage = error.localizedDescription
        let prefix = "AMON_ROUTE_BOOTSTRAP|"
        guard rawMessage.hasPrefix(prefix) else {
            return nil
        }

        let payload = rawMessage.dropFirst(prefix.count)
        let parts = payload.split(separator: "|", maxSplits: 2, omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3 else {
            return LocalRouteRelayStatusSnapshot(
                state: .unavailable,
                code: "relay_status_parse_failed",
                detail: "Amon received a malformed routed-local bootstrap error from the tunnel provider."
            )
        }

        let state = LocalRouteRelayAuthState(rawValue: parts[0]) ?? .unavailable
        let code = parts[1].isEmpty ? nil : parts[1]
        let detail = parts[2].isEmpty ? nil : parts[2]
        return LocalRouteRelayStatusSnapshot(
            state: state,
            code: code,
            detail: detail
        )
    }

    private func configurationSummary(for settings: TransportPrivacySettings) -> String {
        let endpoint = settings.endpoint
        return "host=\(endpoint.serverHost.isEmpty ? "<empty>" : endpoint.serverHost) port=\(endpoint.serverPort) client=\(endpoint.clientAddress) remote=\(endpoint.remoteAddress) mtu=\(endpoint.mtu) dns=\(endpoint.dnsServers.joined(separator: ","))"
    }

    private func configurationSummary(from manager: NETunnelProviderManager) -> String {
        guard let configuration = manager.protocolConfiguration as? NETunnelProviderProtocol else {
            return "providerConfiguration=<missing>"
        }

        let providerConfiguration = configuration.providerConfiguration ?? [:]
        let host = providerConfiguration[ConfigurationKey.serverHost] ?? "<missing>"
        let port = providerConfiguration[ConfigurationKey.serverPort] ?? "<missing>"
        let client = providerConfiguration[ConfigurationKey.clientAddress] ?? "<missing>"
        let remote = providerConfiguration[ConfigurationKey.remoteAddress] ?? "<missing>"
        let mtu = providerConfiguration[ConfigurationKey.mtu] ?? "<missing>"
        let dns = (providerConfiguration[ConfigurationKey.dnsServers] as? [String])?.joined(separator: ",") ?? "<missing>"
        let routeSessionID = providerConfiguration[ConfigurationKey.routeSessionID] as? String ?? "<missing>"
        let routeExpiresAt = providerConfiguration[ConfigurationKey.routeExpiresAt] as? String ?? "<missing>"
        return "bundle=\(configuration.providerBundleIdentifier ?? "<nil>") host=\(host) port=\(port) client=\(client) remote=\(remote) mtu=\(mtu) dns=\(dns) routeSession=\(routeSessionID) routeExpiresAt=\(routeExpiresAt)"
    }

    private func monitorStartTransition(for manager: NETunnelProviderManager) async {
        for attempt in 1...Self.startTransitionPollCount {
            let status = manager.connection.status
            log("Post-start status poll \(attempt): \(describe(status))")
            if status != .invalid && status != .disconnected {
                return
            }
            try? await Task.sleep(nanoseconds: Self.startTransitionPollDelayNanoseconds)
        }

        let finalStatus = manager.connection.status
        if finalStatus == .invalid || finalStatus == .disconnected {
            await refreshRouteRelayStatus(for: manager)
            let message = "iOS accepted the start request but the provider never reached a connecting state. Check PacketTunnelProvider logs in the device console."
            log(message, level: .error)
            statusSnapshot = TransportTunnelStatusSnapshot(
                state: .failed,
                detail: message
            )
        }
    }

    private func describe(_ status: NEVPNStatus) -> String {
        switch status {
        case .invalid:
            return "invalid"
        case .disconnected:
            return "disconnected"
        case .connecting:
            return "connecting"
        case .connected:
            return "connected"
        case .reasserting:
            return "reasserting"
        case .disconnecting:
            return "disconnecting"
        @unknown default:
            return "unknown(\(status.rawValue))"
        }
    }

    private func humanReadableMessage(for error: Error) -> String {
        if let routeRelayStatus = parsedRouteRelayStatus(from: error) {
            return routeRelayStatus.detail ?? "Amon could not complete the routed-local relay bootstrap."
        }

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

    private func errorDescription(for error: Error) -> String {
        let nsError = error as NSError
        return "\(nsError.domain) code=\(nsError.code) \(humanReadableMessage(for: error))"
    }

    private func makeStartOptions(from settings: TransportPrivacySettings, routeSession: RouteSessionStateDTO?) -> [String: NSObject] {
        [
            StartOptionKey.requestedAt: ISO8601DateFormatter().string(from: Date()) as NSString,
            StartOptionKey.requestedHost: settings.endpoint.serverHost as NSString,
            StartOptionKey.requestedPort: NSNumber(value: settings.endpoint.serverPort),
            StartOptionKey.providerBundleIdentifier: providerBundleIdentifier as NSString,
            "routeSessionID": (routeSession?.session_id ?? "<missing>") as NSString,
        ]
    }

    private func intValue(_ value: Any?) -> Int? {
        if let intValue = value as? Int {
            return intValue
        }
        if let numberValue = value as? NSNumber {
            return numberValue.intValue
        }
        return nil
    }

    private func stringArrayValue(_ value: Any?) -> [String]? {
        if let array = value as? [String] {
            return array
        }
        if let array = value as? [NSString] {
            return array.map(String.init)
        }
        if let array = value as? NSArray {
            return array.compactMap { $0 as? String }
        }
        return nil
    }

    private func log(_ message: String, level: OSLogType = .info) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let entry = "\(timestamp) \(message)"
        diagnostics.append(entry)
        if diagnostics.count > 40 {
            diagnostics.removeFirst(diagnostics.count - 40)
        }

        switch level {
        case .debug:
            Self.logger.debug("\(message, privacy: .public)")
        case .error, .fault:
            Self.logger.error("\(message, privacy: .public)")
        default:
            Self.logger.info("\(message, privacy: .public)")
        }
        NSLog("[AmonTunnelManager] %@", message)
    }
}

private enum TunnelConfigurationError: LocalizedError {
    case providerMissing(expectedBundleIdentifier: String)
    case invalidEndpointHost(String)
    case invalidPort
    case routeSessionMissing
    case routeSessionInactive
    case routeSessionExpired

    var errorDescription: String? {
        switch self {
        case .providerMissing(let expectedBundleIdentifier):
            return "The Amon Tunnel extension (\(expectedBundleIdentifier)) is not embedded in this build. Rebuild the app with the Packet Tunnel extension target included."
        case .invalidEndpointHost(let message):
            return message
        case .invalidPort:
            return "Use a valid tunnel port between 1 and 65535."
        case .routeSessionMissing:
            return "Amon could not mint a routed-local session for this tunnel start."
        case .routeSessionInactive:
            return "The routed-local session is no longer active. Refresh it before reconnecting."
        case .routeSessionExpired:
            return "The routed-local session expired before the tunnel could start."
        }
    }
}

private struct RouteRelayStatusResponse: Decodable {
    let state: String
    let code: String?
    let detail: String?
    let session_id: String?
    let auth_session_id: String?
    let expires_at: String?
    let packet_plane_ready: Bool?
    let forwarding_mode: String?
    let forwarding_ready: Bool?

    var snapshot: LocalRouteRelayStatusSnapshot {
        LocalRouteRelayStatusSnapshot(
            state: LocalRouteRelayAuthState(rawValue: state) ?? .unavailable,
            code: code,
            detail: detail,
            sessionID: session_id,
            authSessionID: auth_session_id,
            expiresAt: expires_at.flatMap { ISO8601DateFormatter().date(from: $0) },
            packetPlaneReady: packet_plane_ready,
            forwardingMode: forwarding_mode,
            forwardingReady: forwarding_ready
        )
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
