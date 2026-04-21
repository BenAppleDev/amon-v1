import XCTest
@testable import AmonKit

@MainActor
final class BrowseOpenOrchestratorTests: XCTestCase {
    func testPresentChoicesFetchesAndCachesServeDecision() async {
        let apiClient = BrowseOpenMockAPIClient()
        apiClient.serveDecisionResponse = ServeDecisionResponseDTO(
            disposition: .recommendProtected,
            reason_code: "recommend_protected",
            confidence: 0.91,
            policy_version: "test-policy",
            site_class: "public_dynamic",
            budget_tier: "standard"
        )
        let orchestrator = BrowseOpenOrchestrator(apiClient: apiClient)
        let target = BrowseOpenTarget(title: "Example", url: URL(string: "https://example.com/page")!)

        await orchestrator.presentChoices(for: target)
        await orchestrator.presentChoices(for: target)

        XCTAssertEqual(apiClient.serveDecisionRequests.count, 1)
        XCTAssertEqual(orchestrator.activeChoice?.decision?.disposition, .recommendProtected)
        XCTAssertEqual(orchestrator.activeChoice?.dialogTitle, "Protected Session Recommended")
        XCTAssertEqual(orchestrator.activeChoice?.protectedSessionTitle, "Open Protected Session (Recommended)")
        XCTAssertEqual(orchestrator.activeChoice?.localRoutedTitle, "Open Local (Falls Back to Direct)")
        XCTAssertTrue(orchestrator.activeChoice?.showsProtectedSession ?? false)
        XCTAssertTrue(orchestrator.activeChoice?.showsDirectFallback ?? false)
    }

    func testPresentChoicesFallsBackToLocalChoiceWhenDecisionFails() async {
        let apiClient = BrowseOpenMockAPIClient()
        apiClient.serveDecisionError = URLError(.cannotConnectToHost)
        let orchestrator = BrowseOpenOrchestrator(apiClient: apiClient)
        let target = BrowseOpenTarget(title: "Example", url: URL(string: "https://example.com/page")!)

        await orchestrator.presentChoices(for: target)

        XCTAssertEqual(apiClient.serveDecisionRequests.count, 1)
        XCTAssertNil(orchestrator.activeChoice?.decision)
        XCTAssertFalse(orchestrator.activeChoice?.showsProtectedSession ?? true)
        XCTAssertEqual(orchestrator.activeChoice?.dialogTitle, "Choose Browse Path")
        XCTAssertEqual(orchestrator.activeChoice?.localRoutedTitle, "Open Local (Falls Back to Direct)")
        XCTAssertTrue(orchestrator.activeChoice?.showsDirectFallback ?? false)
        XCTAssertTrue(orchestrator.activeChoice?.message?.contains("Amon can't reach the backend right now") ?? false)
        XCTAssertTrue(orchestrator.activeChoice?.message?.contains("local browsing currently uses direct fallback") ?? false)
    }

    func testLocalOnlyDecisionExplainsProtectedSessionIsUnavailable() async {
        let apiClient = BrowseOpenMockAPIClient()
        apiClient.serveDecisionResponse = ServeDecisionResponseDTO(
            disposition: .deny,
            reason_code: "uncertain_local_only",
            confidence: 0.22,
            policy_version: "test-policy",
            site_class: nil,
            budget_tier: "standard"
        )
        let orchestrator = BrowseOpenOrchestrator(apiClient: apiClient)
        let target = BrowseOpenTarget(title: "Example", url: URL(string: "https://example.com/page")!)

        await orchestrator.presentChoices(for: target)

        XCTAssertEqual(orchestrator.activeChoice?.dialogTitle, "Local Browsing")
        XCTAssertFalse(orchestrator.activeChoice?.showsProtectedSession ?? true)
        XCTAssertTrue(orchestrator.activeChoice?.showsDirectFallback ?? false)
        XCTAssertTrue(orchestrator.activeChoice?.message?.contains("Protected Session is not offered") ?? false)
    }

    func testOpenClearsChoiceAndPresentsRequestedPath() async throws {
        let apiClient = BrowseOpenMockAPIClient()
        let orchestrator = BrowseOpenOrchestrator(apiClient: apiClient)
        let target = BrowseOpenTarget(title: "Example", url: URL(string: "https://example.com/page")!)

        await orchestrator.presentChoices(for: target)
        let choice = try XCTUnwrap(orchestrator.activeChoice)

        orchestrator.open(.cleanView, from: choice)

        XCTAssertNil(orchestrator.activeChoice)
        XCTAssertEqual(orchestrator.presentedPage?.title, "Example")
        XCTAssertEqual(orchestrator.presentedPage?.url, target.url)
        XCTAssertEqual(orchestrator.presentedPage?.requestedPath, .cleanView)
        XCTAssertEqual(orchestrator.presentedPage?.effectivePath, .cleanView)
    }

    func testOpenLocalRoutedUsesDirectFallbackWhenRouteUnavailable() {
        let apiClient = BrowseOpenMockAPIClient()
        let orchestrator = BrowseOpenOrchestrator(apiClient: apiClient)
        let target = BrowseOpenTarget(title: "Example", url: URL(string: "https://example.com/page")!)

        orchestrator.open(.localRouted, for: target)

        XCTAssertEqual(orchestrator.presentedPage?.requestedPath, .localRouted)
        XCTAssertEqual(orchestrator.presentedPage?.effectivePath, .directFallback)
        XCTAssertEqual(orchestrator.presentedPage?.localRouteState, .unavailable)
        XCTAssertTrue(orchestrator.presentedPage?.fallbackReason?.contains("not available in this build yet") ?? false)
    }

    func testOpenLocalRoutedStaysLocalWhenRouteConnected() {
        let apiClient = BrowseOpenMockAPIClient()
        let orchestrator = BrowseOpenOrchestrator(
            apiClient: apiClient,
            localRouteStateProvider: { .connected }
        )
        let target = BrowseOpenTarget(title: "Example", url: URL(string: "https://example.com/page")!)

        orchestrator.open(.localRouted, for: target)

        XCTAssertEqual(orchestrator.presentedPage?.requestedPath, .localRouted)
        XCTAssertEqual(orchestrator.presentedPage?.effectivePath, .localRouted)
        XCTAssertEqual(orchestrator.presentedPage?.localRouteState, .connected)
        XCTAssertNil(orchestrator.presentedPage?.fallbackReason)
    }
}

private final class BrowseOpenMockAPIClient: @unchecked Sendable, AmonAPIClienting {
    var serveDecisionResponse = ServeDecisionResponseDTO(
        disposition: .allowLocal,
        reason_code: "uncertain_local_only",
        confidence: 0.35,
        policy_version: "test-policy",
        site_class: nil,
        budget_tier: "standard"
    )
    var serveDecisionError: Error?
    var serveDecisionRequests: [(String, ServeDecisionIntentDTO)] = []

    func devLogin(appleSubject: String) async throws -> AuthResponseDTO {
        AuthResponseDTO(
            access_token: "token",
            token_type: "bearer",
            expires_at: Date().ISO8601Format(),
            user: UserDTO(id: "user_1", status: "active", entitlement_tier: "full_access", entitlement_status: "active")
        )
    }

    func me() async throws -> UserDTO {
        UserDTO(id: "user_1", status: "active", entitlement_tier: "full_access", entitlement_status: "active")
    }

    func search(query: String, count: Int) async throws -> [SearchResult] {
        []
    }

    func retrieve(url: String) async throws -> StructuredRetrievalDTO {
        StructuredRetrievalDTO(
            url: url,
            canonical_url: url,
            title: "Title",
            domain: "example.com",
            excerpt: nil,
            bullet_points: [],
            retrieved_at: Date()
        )
    }

    func serveDecision(url: String, intent: ServeDecisionIntentDTO) async throws -> ServeDecisionResponseDTO {
        serveDecisionRequests.append((url, intent))
        if let serveDecisionError {
            throw serveDecisionError
        }
        return serveDecisionResponse
    }

    func createProtectedSession(url: String) async throws -> ProtectedSessionStateDTO {
        makeProtectedSessionState()
    }

    func makeProtectedSessionStreamRequest(sessionID: String) throws -> URLRequest {
        URLRequest(url: URL(string: "wss://example.com/v1/protected-sessions/\(sessionID)/stream")!)
    }

    func getProtectedSessionState(sessionID: String) async throws -> ProtectedSessionStateDTO {
        makeProtectedSessionState()
    }

    func sendProtectedSessionAction(
        sessionID: String,
        action: ProtectedSessionActionRequestDTO
    ) async throws -> ProtectedSessionStateDTO {
        makeProtectedSessionState()
    }

    func endProtectedSession(sessionID: String) async throws -> ProtectedSessionEndResponseDTO {
        ProtectedSessionEndResponseDTO(session_id: sessionID, status: "ended")
    }

    func compare(title: String, items: [Item]) async throws -> CompareResponseDTO {
        CompareResponseDTO(title: title, summary: "Summary", rows: [])
    }

    func research(title: String, promptContext: String?, items: [Item]) async throws -> ResearchResponseDTO {
        ResearchResponseDTO(
            title: title,
            summary_text: "Summary",
            bullet_summary: [],
            sources: [],
            model: ModelInfoDTO(name: "mock", version: "1")
        )
    }

    func clearSession() throws {}

    private func makeProtectedSessionState() -> ProtectedSessionStateDTO {
        ProtectedSessionStateDTO(
            session_id: "protected_1",
            status: "active",
            allowed_host: "example.com",
            started_at: Date(),
            expires_at: Date().addingTimeInterval(600),
            last_activity_at: Date(),
            can_go_back: false,
            can_go_forward: false,
            content_revision: 1,
            runtime_kind: "visual_stream_session",
            stream_transport: "websocket",
            worker_id: "worker_local_visual_stream_1",
            worker_type: "visual_stream_session",
            worker_state: "live",
            worker_health: "healthy",
            current_frame: nil,
            current_page: nil,
            detail_message: nil
        )
    }
}
