import Foundation

public enum ProtectedSessionFailurePresentation: Equatable, Sendable {
    case unavailable(message: String)
    case failed(message: String)

    public var message: String {
        switch self {
        case .unavailable(let message), .failed(let message):
            return message
        }
    }

    public var sessionStatusTitle: String {
        switch self {
        case .unavailable:
            return "Unavailable"
        case .failed:
            return "Failed"
        }
    }

    public var terminalTitle: String {
        switch self {
        case .unavailable:
            return "Protected Session unavailable"
        case .failed:
            return "Protected Session failed"
        }
    }
}

public enum ProtectedSessionLifecycleState: Equatable, Sendable {
    case connecting
    case live
    case expired(message: String?)
    case ended(message: String?)
    case failed(message: String?)
}

public enum ProtectedSessionStreamState: Equatable, Sendable {
    case connecting
    case live
    case reconnecting(attempt: Int)
    case degradedPolling(message: String?)
}

public enum ProtectedSessionActionState: Equatable, Sendable {
    case idle
    case performing(ProtectedSessionActionKindDTO)

    public var isPerforming: Bool {
        if case .performing = self {
            return true
        }
        return false
    }
}

public enum ProtectedSessionClientState: Equatable, Sendable {
    case connecting
    case live
    case reconnecting(attempt: Int)
    case degradedPolling
    case expired
    case ended
    case failed
}

public enum ProtectedSessionBackendStatus: String, Codable, Sendable {
    case creating
    case active
    case terminating
    case closed
    case expired
    case failed
}

public enum ProtectedSessionStreamMessageKind: String, Codable, Sendable {
    case subscribed
    case state
    case terminal
    case heartbeat
    case actionAck = "action_ack"
    case error
}

public extension ProtectedSessionStateDTO {
    var backendStatus: ProtectedSessionBackendStatus? {
        ProtectedSessionBackendStatus(rawValue: status)
    }

    var isTerminalStatus: Bool {
        switch backendStatus {
        case .closed, .expired, .failed:
            return true
        default:
            return false
        }
    }
}

public extension ProtectedSessionStreamMessageDTO {
    var kind: ProtectedSessionStreamMessageKind? {
        ProtectedSessionStreamMessageKind(rawValue: type)
    }
}
