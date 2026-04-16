import Foundation

public enum AmonAPIError: Error, LocalizedError, Sendable {
    case invalidURL
    case unauthorized
    case serverError(statusCode: Int, body: String)
    case decodingError

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL."
        case .unauthorized:
            return "Session is missing or invalid."
        case .serverError(let statusCode, let body):
            return "Server returned status \(statusCode): \(body)"
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
            throw AmonAPIError.serverError(statusCode: -1, body: "Non-HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 401 {
                throw AmonAPIError.unauthorized
            }
            throw AmonAPIError.serverError(statusCode: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }
        do {
            return try JSONDecoder.amon.decode(T.self, from: data)
        } catch {
            throw AmonAPIError.decodingError
        }
    }
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
