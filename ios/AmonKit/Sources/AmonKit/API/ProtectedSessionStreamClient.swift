import Foundation

enum ProtectedSessionStreamClientError: LocalizedError {
    case actionRejected(code: String?, message: String?)
    case disconnected

    var errorDescription: String? {
        switch self {
        case .actionRejected(_, let message):
            return message ?? "That protected-session action was rejected."
        case .disconnected:
            return "The protected-session stream disconnected."
        }
    }
}

final class ProtectedSessionStreamClient {
    private let session: URLSession
    private let task: URLSessionWebSocketTask
    private let decoder = JSONDecoder.amon
    private let encoder = JSONEncoder.amon
    private let onMessage: @Sendable (ProtectedSessionStreamMessageDTO) -> Void
    private let onDisconnect: @Sendable (Error?) -> Void
    private var receiveTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?
    private var pendingActionAcks: [String: CheckedContinuation<Void, Error>] = [:]

    init(
        request: URLRequest,
        onMessage: @escaping @Sendable (ProtectedSessionStreamMessageDTO) -> Void,
        onDisconnect: @escaping @Sendable (Error?) -> Void
    ) {
        self.session = URLSession(configuration: .ephemeral)
        self.task = session.webSocketTask(with: request)
        self.onMessage = onMessage
        self.onDisconnect = onDisconnect
    }

    func connect(lastStreamSequence: Int?) {
        task.resume()
        receiveTask?.cancel()
        pingTask?.cancel()

        receiveTask = Task { [weak self] in
            await self?.receiveLoop()
        }
        pingTask = Task { [weak self] in
            await self?.pingLoop()
        }

        Task { [weak self] in
            try? await self?.send(
                ProtectedSessionStreamClientMessageDTO(
                    type: "subscribe",
                    client_message_id: UUID().uuidString,
                    client_action_id: nil,
                    last_stream_sequence: lastStreamSequence,
                    expected_content_revision: nil,
                    action: nil
                )
            )
        }
    }

    func disconnect() {
        failPendingAcks(with: ProtectedSessionStreamClientError.disconnected)
        receiveTask?.cancel()
        pingTask?.cancel()
        task.cancel(with: .goingAway, reason: nil)
        session.invalidateAndCancel()
    }

    func sendAction(
        action: ProtectedSessionActionRequestDTO,
        clientActionID: String,
        expectedContentRevision: Int?
    ) async throws {
        try await withCheckedThrowingContinuation { continuation in
            pendingActionAcks[clientActionID] = continuation
            Task { [weak self] in
                do {
                    try await self?.send(
                        ProtectedSessionStreamClientMessageDTO(
                            type: "action",
                            client_message_id: UUID().uuidString,
                            client_action_id: clientActionID,
                            last_stream_sequence: nil,
                            expected_content_revision: expectedContentRevision,
                            action: action
                        )
                    )
                } catch {
                    if let continuation = self?.pendingActionAcks.removeValue(forKey: clientActionID) {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    private func send(_ message: ProtectedSessionStreamClientMessageDTO) async throws {
        let data = try encoder.encode(message)
        try await task.send(.data(data))
    }

    private func pingLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled else { break }
            try? await send(
                ProtectedSessionStreamClientMessageDTO(
                    type: "ping",
                    client_message_id: UUID().uuidString,
                    client_action_id: nil,
                    last_stream_sequence: nil,
                    expected_content_revision: nil,
                    action: nil
                )
            )
        }
    }

    private func receiveLoop() async {
        do {
            while !Task.isCancelled {
                let message = try await task.receive()
                let data: Data
                switch message {
                case .data(let rawData):
                    data = rawData
                case .string(let string):
                    data = Data(string.utf8)
                @unknown default:
                    continue
                }

                let decoded = try decoder.decode(ProtectedSessionStreamMessageDTO.self, from: data)
                handleAckIfNeeded(decoded)
                onMessage(decoded)
            }
        } catch {
            guard !Task.isCancelled else { return }
            failPendingAcks(with: error)
            onDisconnect(error)
        }
    }

    private func handleAckIfNeeded(_ message: ProtectedSessionStreamMessageDTO) {
        guard message.type == "action_ack", let clientActionID = message.client_action_id else { return }
        guard let continuation = pendingActionAcks.removeValue(forKey: clientActionID) else { return }
        switch message.action_status {
        case "accepted":
            continuation.resume()
        case "failed", "rejected":
            continuation.resume(
                throwing: ProtectedSessionStreamClientError.actionRejected(
                    code: message.code,
                    message: message.message
                )
            )
        default:
            continuation.resume()
        }
    }

    private func failPendingAcks(with error: Error) {
        let continuations = pendingActionAcks.values
        pendingActionAcks.removeAll()
        for continuation in continuations {
            continuation.resume(throwing: error)
        }
    }
}
