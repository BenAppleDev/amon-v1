import Foundation

public protocol AmonAPIClienting: Sendable {
    func devLogin(appleSubject: String) async throws -> AuthResponseDTO
    func me() async throws -> UserDTO
    func search(query: String, count: Int) async throws -> [SearchResult]
    func retrieve(url: String) async throws -> StructuredRetrievalDTO
    func serveDecision(url: String, intent: ServeDecisionIntentDTO) async throws -> ServeDecisionResponseDTO
    func mintRouteSession() async throws -> RouteSessionStateDTO
    func refreshRouteSession(sessionID: String) async throws -> RouteSessionStateDTO
    func revokeRouteSession(sessionID: String) async throws -> RouteSessionRevokeResponseDTO
    func createProtectedSession(url: String) async throws -> ProtectedSessionStateDTO
    func makeProtectedSessionStreamRequest(sessionID: String) throws -> URLRequest
    func getProtectedSessionState(sessionID: String) async throws -> ProtectedSessionStateDTO
    func sendProtectedSessionAction(
        sessionID: String,
        action: ProtectedSessionActionRequestDTO
    ) async throws -> ProtectedSessionStateDTO
    func endProtectedSession(sessionID: String) async throws -> ProtectedSessionEndResponseDTO
    func compare(title: String, items: [Item]) async throws -> CompareResponseDTO
    func research(title: String, promptContext: String?, items: [Item]) async throws -> ResearchResponseDTO
    func clearSession() throws
}

public extension AmonAPIClienting {
    func mintRouteSession() async throws -> RouteSessionStateDTO {
        throw AmonAPIError.serverError(
            AmonBackendErrorContext(
                statusCode: -1,
                code: "route_session_unimplemented",
                message: "This API client does not implement route-session control."
            )
        )
    }

    func refreshRouteSession(sessionID _: String) async throws -> RouteSessionStateDTO {
        throw AmonAPIError.serverError(
            AmonBackendErrorContext(
                statusCode: -1,
                code: "route_session_unimplemented",
                message: "This API client does not implement route-session control."
            )
        )
    }

    func revokeRouteSession(sessionID _: String) async throws -> RouteSessionRevokeResponseDTO {
        throw AmonAPIError.serverError(
            AmonBackendErrorContext(
                statusCode: -1,
                code: "route_session_unimplemented",
                message: "This API client does not implement route-session control."
            )
        )
    }
}
