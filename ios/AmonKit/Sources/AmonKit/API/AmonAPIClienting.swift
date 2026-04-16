import Foundation

public protocol AmonAPIClienting: Sendable {
    func devLogin(appleSubject: String) async throws -> AuthResponseDTO
    func me() async throws -> UserDTO
    func search(query: String, count: Int) async throws -> [SearchResult]
    func retrieve(url: String) async throws -> StructuredRetrievalDTO
    func serveDecision(url: String, intent: ServeDecisionIntentDTO) async throws -> ServeDecisionResponseDTO
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
