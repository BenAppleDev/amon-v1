import Foundation

public protocol AmonAPIClienting: Sendable {
    func devLogin(appleSubject: String) async throws -> AuthResponseDTO
    func me() async throws -> UserDTO
    func search(query: String, count: Int) async throws -> [SearchResult]
    func retrieve(url: String) async throws -> StructuredRetrievalDTO
    func compare(title: String, items: [Item]) async throws -> CompareResponseDTO
    func research(title: String, promptContext: String?, items: [Item]) async throws -> ResearchResponseDTO
    func clearSession() throws
}
