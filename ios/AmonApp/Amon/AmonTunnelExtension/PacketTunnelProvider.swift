import Foundation
import Network
import NetworkExtension

final class PacketTunnelProvider: NEPacketTunnelProvider {
    fileprivate enum ConfigurationKey {
        static let serverHost = "serverHost"
        static let serverPort = "serverPort"
        static let clientAddress = "clientAddress"
        static let subnetMask = "subnetMask"
        static let remoteAddress = "remoteAddress"
        static let dnsServers = "dnsServers"
        static let mtu = "mtu"
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

    private let ioQueue = DispatchQueue(label: "com.benappledev.AmonTunnelExtension.io")
    private var tunnelConnection: NWConnection?
    private var receiveBuffer = Data()
    private var didCompleteStart = false
    private var isTunnelRunning = false

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        do {
            let configuration = try DevTunnelConfiguration(protocolConfiguration: protocolConfiguration)
            let connection = try makeConnection(for: configuration)
            tunnelConnection = connection

            connection.stateUpdateHandler = { [weak self] state in
                guard let self else { return }

                switch state {
                case .ready:
                    self.beginTunnelSession(using: configuration, completionHandler: completionHandler)
                case .failed(let error):
                    self.completeStartIfNeeded(with: error, completionHandler: completionHandler)
                    self.cancelTunnelWithError(error)
                case .cancelled:
                    if self.isTunnelRunning {
                        self.cancelTunnelWithError(TunnelProviderError.connectionClosed)
                    } else {
                        self.completeStartIfNeeded(with: TunnelProviderError.connectionClosed, completionHandler: completionHandler)
                    }
                default:
                    break
                }
            }

            connection.start(queue: ioQueue)
        } catch {
            completeStartIfNeeded(with: error, completionHandler: completionHandler)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        isTunnelRunning = false
        tunnelConnection?.cancel()
        tunnelConnection = nil
        receiveBuffer.removeAll(keepingCapacity: false)
        completionHandler()
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil) {
        completionHandler?(messageData)
    }

    private func beginTunnelSession(
        using configuration: DevTunnelConfiguration,
        completionHandler: @escaping (Error?) -> Void
    ) {
        performHandshake { [weak self] result in
            guard let self else { return }

            switch result {
            case .failure(let error):
                self.completeStartIfNeeded(with: error, completionHandler: completionHandler)
                self.cancelTunnelWithError(error)

            case .success:
                Task {
                    do {
                        try await self.applyTunnelNetworkSettings(using: configuration)
                        self.isTunnelRunning = true
                        self.completeStartIfNeeded(with: nil, completionHandler: completionHandler)
                        self.startReadingPacketsFromDevice()
                        self.startReadingPacketsFromServer()
                    } catch {
                        self.completeStartIfNeeded(with: error, completionHandler: completionHandler)
                        self.cancelTunnelWithError(error)
                    }
                }
            }
        }
    }

    private func makeConnection(for configuration: DevTunnelConfiguration) throws -> NWConnection {
        guard let port = NWEndpoint.Port(rawValue: UInt16(configuration.serverPort)) else {
            throw TunnelProviderError.invalidConfiguration("Set a valid tunnel port before connecting.")
        }
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

                guard !isComplete, let data, let reply = String(data: data, encoding: .utf8)?
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

        packetFlow.readPackets { [weak self] packets, _ in
            guard let self else { return }
            guard self.isTunnelRunning else { return }

            if packets.isEmpty {
                self.startReadingPacketsFromDevice()
                return
            }

            for packet in packets {
                self.sendPacketToServer(packet)
            }

            self.startReadingPacketsFromDevice()
        }
    }

    private func sendPacketToServer(_ packet: Data) {
        guard let tunnelConnection else { return }

        var length = UInt16(packet.count).bigEndian
        let frame = Data(bytes: &length, count: MemoryLayout<UInt16>.size) + packet
        tunnelConnection.send(content: frame, completion: .contentProcessed { [weak self] error in
            guard let self else { return }
            if let error {
                self.cancelTunnelWithError(error)
            }
        })
    }

    private func startReadingPacketsFromServer() {
        guard let tunnelConnection, isTunnelRunning else { return }

        tunnelConnection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }

            if let error {
                self.cancelTunnelWithError(error)
                return
            }

            if let data, !data.isEmpty {
                self.receiveBuffer.append(data)
                self.flushReceivedFramesToPacketFlow()
            }

            if isComplete {
                self.cancelTunnelWithError(TunnelProviderError.connectionClosed)
                return
            }

            self.startReadingPacketsFromServer()
        }
    }

    private func flushReceivedFramesToPacketFlow() {
        while receiveBuffer.count >= 2 {
            let packetLength = receiveBuffer.prefix(2).withUnsafeBytes { rawBuffer -> Int in
                Int(rawBuffer.load(as: UInt16.self).bigEndian)
            }

            let totalFrameLength = 2 + packetLength
            guard receiveBuffer.count >= totalFrameLength else { return }

            let packet = receiveBuffer.subdata(in: 2..<totalFrameLength)
            receiveBuffer.removeSubrange(0..<totalFrameLength)

            let protocolNumber = packetProtocolNumber(for: packet)
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
        completionHandler(error)
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

    init(protocolConfiguration: NEVPNProtocol) throws {
        guard let providerProtocol = protocolConfiguration as? NETunnelProviderProtocol,
              let providerConfiguration = providerProtocol.providerConfiguration
        else {
            throw PacketTunnelProvider.TunnelProviderError.invalidConfiguration("Amon couldn't read the tunnel provider configuration.")
        }

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
