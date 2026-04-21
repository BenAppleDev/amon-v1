import Foundation
import Network
import NetworkExtension
import OSLog

final class PacketTunnelProvider: NEPacketTunnelProvider {
    fileprivate enum ConfigurationKey {
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

    fileprivate enum TunnelProviderError: LocalizedError {
        case invalidConfiguration(String)
        case handshakeFailed
        case connectionClosed

        var errorDescription: String? {
            switch self {
            case .invalidConfiguration(let message):
                return message
            case .handshakeFailed:
                return "The laptop endpoint did not accept the Amon tunnel handshake."
            case .connectionClosed:
                return "The laptop endpoint closed the tunnel connection."
            }
        }
    }

    private let logger = Logger(subsystem: "com.benappledev.Amon", category: "PacketTunnelProvider")
    private let ioQueue = DispatchQueue(label: "com.benappledev.AmonTunnelExtension.io")
    private var tunnelConnection: NWConnection?
    private var receiveBuffer = Data()
    private var didCompleteStart = false
    private var isTunnelRunning = false

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        resetForNewStartAttempt()
        log("startTunnel entered with options \(options?.description ?? "<nil>")")
        log("protocolConfiguration type is \(String(describing: type(of: protocolConfiguration)))")

        do {
            let configuration = try DevTunnelConfiguration(protocolConfiguration: protocolConfiguration)
            log("Parsed tunnel configuration \(configuration.summary)")

            let connection = try makeConnection(for: configuration)
            tunnelConnection = connection
            log("Created NWConnection to \(configuration.serverHost):\(configuration.serverPort)")

            connection.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                self.log("NWConnection state changed to \(String(describing: state))")

                switch state {
                case .ready:
                    self.log("TCP connection is ready; beginning handshake")
                    self.beginTunnelSession(using: configuration, completionHandler: completionHandler)
                case .failed(let error):
                    self.log("TCP connection failed before tunnel was established: \(error.localizedDescription)")
                    self.completeStartIfNeeded(with: error, completionHandler: completionHandler)
                    self.cancelTunnelWithError(error)
                case .cancelled:
                    self.log("TCP connection was cancelled")
                    if self.isTunnelRunning {
                        self.cancelTunnelWithError(TunnelProviderError.connectionClosed)
                    } else {
                        self.completeStartIfNeeded(with: TunnelProviderError.connectionClosed, completionHandler: completionHandler)
                    }
                default:
                    break
                }
            }

            log("Starting TCP connection attempt to laptop endpoint")
            connection.start(queue: ioQueue)
        } catch {
            log("startTunnel failed before TCP connect: \(error.localizedDescription)")
            completeStartIfNeeded(with: error, completionHandler: completionHandler)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        log("stopTunnel entered with reason \(reason.rawValue)")
        isTunnelRunning = false
        tunnelConnection?.cancel()
        tunnelConnection = nil
        receiveBuffer.removeAll(keepingCapacity: false)
        completionHandler()
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil) {
        log("Received app message of \(messageData.count) bytes")
        completionHandler?(messageData)
    }

    private func beginTunnelSession(
        using configuration: DevTunnelConfiguration,
        completionHandler: @escaping (Error?) -> Void
    ) {
        log("Beginning tunnel session using configuration \(configuration.summary)")

        performHandshake { [weak self] result in
            guard let self else { return }

            switch result {
            case .failure(let error):
                self.log("Handshake failed: \(error.localizedDescription)")
                self.completeStartIfNeeded(with: error, completionHandler: completionHandler)
                self.cancelTunnelWithError(error)

            case .success:
                self.log("Handshake succeeded; applying NEPacketTunnelNetworkSettings")
                Task {
                    do {
                        try await self.applyTunnelNetworkSettings(using: configuration)
                        self.isTunnelRunning = true
                        self.log("Tunnel network settings applied successfully; starting packet loops")
                        self.completeStartIfNeeded(with: nil, completionHandler: completionHandler)
                        self.startReadingPacketsFromDevice()
                        self.startReadingPacketsFromServer()
                    } catch {
                        self.log("Applying tunnel network settings failed: \(error.localizedDescription)")
                        self.completeStartIfNeeded(with: error, completionHandler: completionHandler)
                        self.cancelTunnelWithError(error)
                    }
                }
            }
        }
    }

    private func makeConnection(for configuration: DevTunnelConfiguration) throws -> NWConnection {
        let normalizedHost = configuration.serverHost.lowercased()
        guard let port = NWEndpoint.Port(rawValue: UInt16(configuration.serverPort)) else {
            throw TunnelProviderError.invalidConfiguration("Set a valid tunnel port before connecting.")
        }

        guard !configuration.serverHost.contains("://") else {
            throw TunnelProviderError.invalidConfiguration("Use only a laptop host or IP address. Leave out http:// or https://.")
        }

        guard !["localhost", "127.0.0.1", "::1", "0.0.0.0"].contains(normalizedHost) else {
            throw TunnelProviderError.invalidConfiguration("Use your laptop's LAN IP address for the tunnel host, not localhost or 0.0.0.0.")
        }

        log("Resolving laptop endpoint \(configuration.serverHost):\(configuration.serverPort)")
        return NWConnection(
            host: NWEndpoint.Host(configuration.serverHost),
            port: port,
            using: .tcp
        )
    }

    private func performHandshake(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let tunnelConnection else {
            completion(.failure(TunnelProviderError.connectionClosed))
            return
        }

        let greeting = Data("AMON/1\n".utf8)
        log("Sending handshake request AMON/1")
        tunnelConnection.send(content: greeting, completion: .contentProcessed { sendError in
            if let sendError {
                completion(.failure(sendError))
                return
            }

            tunnelConnection.receive(minimumIncompleteLength: 1, maximumLength: 64) { data, _, isComplete, error in
                if let error {
                    completion(.failure(error))
                    return
                }

                self.log("Received handshake response bytes=\(data?.count ?? 0) isComplete=\(isComplete)")

                guard !isComplete,
                      let data,
                      let reply = String(data: data, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines),
                      reply == "AMON/1 OK"
                else {
                    completion(.failure(TunnelProviderError.handshakeFailed))
                    return
                }

                completion(.success(()))
            }
        })
    }

    private func applyTunnelNetworkSettings(using configuration: DevTunnelConfiguration) async throws {
        let networkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: configuration.remoteAddress)
        log("Applying tunnel settings remote=\(configuration.remoteAddress) client=\(configuration.clientAddress) subnet=\(configuration.subnetMask) mtu=\(configuration.mtu) dns=\(configuration.dnsServers.joined(separator: ","))")

        let ipv4Settings = NEIPv4Settings(
            addresses: [configuration.clientAddress],
            subnetMasks: [configuration.subnetMask]
        )
        ipv4Settings.includedRoutes = [NEIPv4Route.default()]
        networkSettings.ipv4Settings = ipv4Settings

        if !configuration.dnsServers.isEmpty {
            let dnsSettings = NEDNSSettings(servers: configuration.dnsServers)
            dnsSettings.matchDomains = [""]
            networkSettings.dnsSettings = dnsSettings
        }

        networkSettings.mtu = NSNumber(value: configuration.mtu)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            setTunnelNetworkSettings(networkSettings) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func startReadingPacketsFromDevice() {
        guard isTunnelRunning else { return }
        log("Starting packetFlow.readPackets loop")

        packetFlow.readPackets { [weak self] packets, _ in
            guard let self else { return }
            guard self.isTunnelRunning else { return }

            if packets.isEmpty {
                self.startReadingPacketsFromDevice()
                return
            }

            for packet in packets {
                self.log("Read packet from device length=\(packet.count)")
                self.sendPacketToServer(packet)
            }

            self.startReadingPacketsFromDevice()
        }
    }

    private func sendPacketToServer(_ packet: Data) {
        guard let tunnelConnection else { return }

        var length = UInt16(packet.count).bigEndian
        let frame = Data(bytes: &length, count: MemoryLayout<UInt16>.size) + packet
        log("Sending framed packet to server length=\(packet.count)")
        tunnelConnection.send(content: frame, completion: .contentProcessed { [weak self] error in
            guard let self else { return }
            if let error {
                self.log("Sending packet to server failed: \(error.localizedDescription)")
                self.cancelTunnelWithError(error)
            }
        })
    }

    private func startReadingPacketsFromServer() {
        guard let tunnelConnection, isTunnelRunning else { return }
        log("Starting server-to-device receive loop")

        tunnelConnection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }

            if let error {
                self.log("Server receive loop failed: \(error.localizedDescription)")
                self.cancelTunnelWithError(error)
                return
            }

            if let data, !data.isEmpty {
                self.log("Received framed data from server bytes=\(data.count)")
                self.receiveBuffer.append(data)
                self.flushReceivedFramesToPacketFlow()
            }

            if isComplete {
                self.log("Server closed the connection")
                self.cancelTunnelWithError(TunnelProviderError.connectionClosed)
                return
            }

            self.startReadingPacketsFromServer()
        }
    }

    private func flushReceivedFramesToPacketFlow() {
        while receiveBuffer.count >= 2 {
            let packetLength = Int(receiveBuffer[receiveBuffer.startIndex]) << 8
                | Int(receiveBuffer[receiveBuffer.startIndex.advanced(by: 1)])

            let totalFrameLength = 2 + packetLength
            guard receiveBuffer.count >= totalFrameLength else { return }

            let packet = receiveBuffer.subdata(in: 2..<totalFrameLength)
            receiveBuffer.removeSubrange(0..<totalFrameLength)

            let protocolNumber = packetProtocolNumber(for: packet)
            log("Writing packet back to device length=\(packet.count) protocol=\(protocolNumber)")
            packetFlow.writePackets([packet], withProtocols: [protocolNumber])
        }
    }

    private func packetProtocolNumber(for packet: Data) -> NSNumber {
        guard let version = packet.first.map({ ($0 & 0xF0) >> 4 }) else {
            return NSNumber(value: AF_INET)
        }
        if version == 6 {
            return NSNumber(value: AF_INET6)
        }
        return NSNumber(value: AF_INET)
    }

    private func completeStartIfNeeded(with error: Error?, completionHandler: @escaping (Error?) -> Void) {
        guard !didCompleteStart else { return }
        didCompleteStart = true
        if let error {
            log("Completing tunnel start with error: \(error.localizedDescription)")
        } else {
            log("Completing tunnel start successfully")
        }
        completionHandler(error)
    }

    private func resetForNewStartAttempt() {
        log("Resetting provider state for a new tunnel start attempt")
        didCompleteStart = false
        isTunnelRunning = false
        receiveBuffer.removeAll(keepingCapacity: false)
        tunnelConnection?.cancel()
        tunnelConnection = nil
    }

    private func log(_ message: String) {
        logger.info("\(message, privacy: .public)")
        NSLog("[AmonPacketTunnel] %@", message)
    }
}

private struct DevTunnelConfiguration {
    let serverHost: String
    let serverPort: Int
    let clientAddress: String
    let subnetMask: String
    let remoteAddress: String
    let dnsServers: [String]
    let mtu: Int
    let routeSessionID: String
    let routeAccessToken: String
    let routeExpiresAt: String
    let routeAuthSessionID: String

    var summary: String {
        "host=\(serverHost) port=\(serverPort) client=\(clientAddress) remote=\(remoteAddress) mtu=\(mtu) dns=\(dnsServers.joined(separator: ",")) routeSession=\(routeSessionID) routeExpiresAt=\(routeExpiresAt)"
    }

    init(protocolConfiguration: NEVPNProtocol) throws {
        guard let providerProtocol = protocolConfiguration as? NETunnelProviderProtocol,
              let providerConfiguration = providerProtocol.providerConfiguration
        else {
            throw PacketTunnelProvider.TunnelProviderError.invalidConfiguration("Amon couldn't read the tunnel provider configuration.")
        }

        NSLog("[AmonPacketTunnel] providerConfiguration keys=%@", providerConfiguration.keys.sorted().description)
        NSLog(
            "[AmonPacketTunnel] providerBundleIdentifier=%@ serverAddress=%@",
            providerProtocol.providerBundleIdentifier ?? "<nil>",
            providerProtocol.serverAddress ?? "<nil>"
        )

        serverHost = try DevTunnelConfiguration.stringValue(
            for: PacketTunnelProvider.ConfigurationKey.serverHost,
            in: providerConfiguration
        )
        serverPort = try DevTunnelConfiguration.intValue(
            for: PacketTunnelProvider.ConfigurationKey.serverPort,
            in: providerConfiguration
        )
        clientAddress = try DevTunnelConfiguration.stringValue(
            for: PacketTunnelProvider.ConfigurationKey.clientAddress,
            in: providerConfiguration
        )
        subnetMask = try DevTunnelConfiguration.stringValue(
            for: PacketTunnelProvider.ConfigurationKey.subnetMask,
            in: providerConfiguration
        )
        remoteAddress = try DevTunnelConfiguration.stringValue(
            for: PacketTunnelProvider.ConfigurationKey.remoteAddress,
            in: providerConfiguration
        )
        mtu = try DevTunnelConfiguration.intValue(
            for: PacketTunnelProvider.ConfigurationKey.mtu,
            in: providerConfiguration
        )
        dnsServers = (providerConfiguration[PacketTunnelProvider.ConfigurationKey.dnsServers] as? [String]) ?? []
        routeSessionID = try DevTunnelConfiguration.stringValue(
            for: PacketTunnelProvider.ConfigurationKey.routeSessionID,
            in: providerConfiguration
        )
        routeAccessToken = try DevTunnelConfiguration.stringValue(
            for: PacketTunnelProvider.ConfigurationKey.routeAccessToken,
            in: providerConfiguration
        )
        routeExpiresAt = try DevTunnelConfiguration.stringValue(
            for: PacketTunnelProvider.ConfigurationKey.routeExpiresAt,
            in: providerConfiguration
        )
        routeAuthSessionID = try DevTunnelConfiguration.stringValue(
            for: PacketTunnelProvider.ConfigurationKey.routeAuthSessionID,
            in: providerConfiguration
        )
    }

    private static func stringValue(for key: String, in configuration: [String: Any]) throws -> String {
        guard let value = configuration[key] as? String,
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw PacketTunnelProvider.TunnelProviderError.invalidConfiguration("Missing tunnel setting for \(key).")
        }
        return value
    }

    private static func intValue(for key: String, in configuration: [String: Any]) throws -> Int {
        if let value = configuration[key] as? Int {
            return value
        }
        if let value = configuration[key] as? NSNumber {
            return value.intValue
        }
        throw PacketTunnelProvider.TunnelProviderError.invalidConfiguration("Missing tunnel setting for \(key).")
    }
}
