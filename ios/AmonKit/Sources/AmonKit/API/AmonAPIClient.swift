import Foundation

public enum AmonAPIError: Error, LocalizedError, Sendable {
    case invalidURL
    case unauthorized
    case serverError(AmonBackendErrorContext)
    case decodingError

    public var statusCode: Int? {
        switch self {
        case .invalidURL, .decodingError:
            return nil
        case .unauthorized:
            return 401
        case .serverError(let context):
            return context.statusCode
        }
    }

    public var backendCode: String? {
        switch self {
        case .serverError(let context):
            return context.code
        default:
            return nil
        }
    }

    public var backendMessage: String? {
        switch self {
        case .invalidURL:
            return nil
        case .unauthorized:
            return "Session is missing or invalid."
        case .serverError(let context):
            return context.message
        case .decodingError:
            return nil
        }
    }

    public var backendContext: AmonBackendErrorContext? {
        switch self {
        case .serverError(let context):
            return context
        default:
            return nil
        }
    }

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL."
        case .unauthorized:
            return "Session is missing or invalid."
        case .serverError(let context):
            if let message = context.message {
                return "Server returned status \(context.statusCode): \(message)"
            }
            return "Server returned status \(context.statusCode)."
        case .decodingError:
            return "Failed to decode server response."
        }
    }
}

public final class AmonAPIClient: @unchecked Sendable, AmonAPIClienting {
    public let baseURL: URL
    private let session: URLSession
    private let keychain: KeychainHelper

    public init(baseURL: URL, session: URLSession? = nil, keychain: KeychainHelper = .shared) {
        self.baseURL = baseURL
        self.session = session ?? .amonDefault
        self.keychain = keychain
    }

    public func devLogin(appleSubject: String) async throws -> AuthResponseDTO {
        let response: AuthResponseDTO = try await request(
            path: "/v1/auth/dev-login",
            method: "POST",
            body: DevLoginRequestDTO(apple_subject: appleSubject),
            requiresAuth: false
        )
        try keychain.saveSessionToken(response.access_token)
        return response
    }

    public func me() async throws -> UserDTO {
        try await request(path: "/v1/me", method: "GET", requiresAuth: true)
    }

    public func search(query: String, count: Int = 10) async throws -> [SearchResult] {
        let payload = SearchRequestDTO(query: query, count: count)
        let response: SearchResponseDTO = try await request(path: "/v1/search", method: "POST", body: payload, requiresAuth: true)
        return response.results
    }

    public func retrieve(url: String) async throws -> StructuredRetrievalDTO {
        try await request(path: "/v1/retrieve", method: "POST", body: RetrieveRequestDTO(url: url), requiresAuth: true)
    }

    public func serveDecision(url: String, intent: ServeDecisionIntentDTO = .open) async throws -> ServeDecisionResponseDTO {
        try await request(
            path: "/v1/protected-sessions/decision",
            method: "POST",
            body: ServeDecisionRequestDTO(url: url, intent: intent),
            requiresAuth: true
        )
    }

    public func createProtectedSession(url: String) async throws -> ProtectedSessionStateDTO {
        try await request(
            path: "/v1/protected-sessions",
            method: "POST",
            body: ProtectedSessionCreateRequestDTO(url: url),
            requiresAuth: true
        )
    }

    public func makeProtectedSessionStreamRequest(sessionID: String) throws -> URLRequest {
        guard
            var components = URLComponents(
                url: baseURL
                    .appendingPathComponent("v1")
                    .appendingPathComponent("protected-sessions")
                    .appendingPathComponent(sessionID)
                    .appendingPathComponent("stream"),
                resolvingAgainstBaseURL: true
            )
        else {
            throw AmonAPIError.invalidURL
        }

        switch components.scheme?.lowercased() {
        case "https":
            components.scheme = "wss"
        case "http":
            components.scheme = "ws"
        default:
            throw AmonAPIError.invalidURL
        }

        guard let url = components.url else {
            throw AmonAPIError.invalidURL
        }

        guard let token = try keychain.readSessionToken() else {
            throw AmonAPIError.unauthorized
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    public func getProtectedSessionState(sessionID: String) async throws -> ProtectedSessionStateDTO {
        try await request(path: "/v1/protected-sessions/\(sessionID)", method: "GET", requiresAuth: true)
    }

    public func sendProtectedSessionAction(
        sessionID: String,
        action: ProtectedSessionActionRequestDTO
    ) async throws -> ProtectedSessionStateDTO {
        try await request(
            path: "/v1/protected-sessions/\(sessionID)/actions",
            method: "POST",
            body: action,
            requiresAuth: true
        )
    }

    public func endProtectedSession(sessionID: String) async throws -> ProtectedSessionEndResponseDTO {
        try await request(path: "/v1/protected-sessions/\(sessionID)", method: "DELETE", requiresAuth: true)
    }

    public func compare(title: String, items: [Item]) async throws -> CompareResponseDTO {
        let payload = CompareRequestDTO(title: title, items: items.map(ItemSourcePayloadDTO.init(item:)))
        return try await request(path: "/v1/compare", method: "POST", body: payload, requiresAuth: true)
    }

    public func research(title: String, promptContext: String?, items: [Item]) async throws -> ResearchResponseDTO {
        let payload = ResearchRequestDTO(title: title, prompt_context: promptContext, items: items.map(ItemSourcePayloadDTO.init(item:)))
        return try await request(path: "/v1/research", method: "POST", body: payload, requiresAuth: true)
    }

    public func clearSession() throws {
        try keychain.deleteSessionToken()
    }

    private func request<T: Decodable, Body: Encodable>(
        path: String,
        method: String,
        body: Body,
        requiresAuth: Bool
    ) async throws -> T {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw AmonAPIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder.amon.encode(body)
        if requiresAuth {
            guard let token = try keychain.readSessionToken() else {
                throw AmonAPIError.unauthorized
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return try await perform(request)
    }

    private func request<T: Decodable>(path: String, method: String, requiresAuth: Bool) async throws -> T {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw AmonAPIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        if requiresAuth {
            guard let token = try keychain.readSessionToken() else {
                throw AmonAPIError.unauthorized
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return try await perform(request)
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AmonAPIError.serverError(
                AmonBackendErrorContext(
                    statusCode: -1,
                    code: "non_http_response",
                    message: "Non-HTTP response"
                )
            )
        }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 401 {
                throw AmonAPIError.unauthorized
            }
            throw AmonAPIError.serverError(decodeBackendErrorContext(statusCode: http.statusCode, data: data))
        }
        do {
            return try JSONDecoder.amon.decode(T.self, from: data)
        } catch {
            throw AmonAPIError.decodingError
        }
    }

    private func decodeBackendErrorContext(statusCode: Int, data: Data) -> AmonBackendErrorContext {
        let rawBody = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty

        if let envelope = try? JSONDecoder.amon.decode(BackendErrorEnvelope.self, from: data) {
            return AmonBackendErrorContext(
                statusCode: statusCode,
                code: envelope.normalizedCode,
                message: envelope.normalizedMessage ?? rawBody
            )
        }

        return AmonBackendErrorContext(
            statusCode: statusCode,
            code: nil,
            message: rawBody
        )
    }
}

private struct BackendErrorEnvelope: Decodable {
    let code: String?
    let message: String?
    let detail: BackendErrorDetail?

    var normalizedCode: String? {
        detail?.code ?? code
    }

    var normalizedMessage: String? {
        detail?.message ?? message
    }
}

private enum BackendErrorDetail: Decodable {
    case string(String)
    case object(BackendErrorObject)

    var code: String? {
        if case .object(let detail) = self {
            return detail.code
        }
        return nil
    }

    var message: String? {
        switch self {
        case .string(let value):
            return value.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        case .object(let detail):
            return detail.message?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        }
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .string(value)
            return
        }
        self = .object(try container.decode(BackendErrorObject.self))
    }
}

private struct BackendErrorObject: Decodable {
    let code: String?
    let message: String?
}

private extension URLSession {
    static let amonDefault: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 10
        return URLSession(configuration: configuration)
    }()
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
