import Foundation
import XCTest
@testable import AmonKit

@MainActor
final class ProtectedSessionViewModelTests: XCTestCase {
    func testStartFailureTransitionsToFailedState() async {
        let apiClient = ProtectedSessionAPIClientStub()
        apiClient.createSessionError = AmonAPIError.serverError(
            AmonBackendErrorContext(
                statusCode: 503,
                code: "protected_session_unavailable",
                message: "Protected Session is unavailable right now."
            )
        )

        let viewModel = ProtectedSessionViewModel(
            url: URL(string: "https://example.com")!,
            apiClient: apiClient,
            streamClientFactory: FakeProtectedSessionStreamClientFactory(),
            reconnectDelay: .seconds(0)
        )

        await viewModel.startIfNeeded()

        XCTAssertEqual(viewModel.clientState, .failed)
        XCTAssertEqual(viewModel.sessionStatusTitle, "Unavailable")
        XCTAssertEqual(viewModel.terminalStateTitle, "Protected Session unavailable")
        XCTAssertTrue(viewModel.terminalStateMessage.contains("unavailable"))
    }

    func testStartFallsBackToDegradedPollingWhenStreamAttachFails() async {
        let apiClient = ProtectedSessionAPIClientStub()
        apiClient.makeStreamRequestError = AmonAPIError.invalidURL

        let viewModel = ProtectedSessionViewModel(
            url: URL(string: "https://example.com")!,
            apiClient: apiClient,
            streamClientFactory: FakeProtectedSessionStreamClientFactory(),
            reconnectDelay: .seconds(0)
        )

        await viewModel.startIfNeeded()

        XCTAssertEqual(viewModel.sessionLifecycleState, .live)
        XCTAssertEqual(viewModel.clientState, .degradedPolling)
        XCTAssertEqual(viewModel.streamStatusLabel, "Polling fallback")
    }

    func testStreamDisconnectTransitionsThroughReconnectToDegradedPolling() async {
        let apiClient = ProtectedSessionAPIClientStub()
        let streamFactory = FakeProtectedSessionStreamClientFactory()
        let viewModel = ProtectedSessionViewModel(
            url: URL(string: "https://example.com")!,
            apiClient: apiClient,
            streamClientFactory: streamFactory,
            reconnectDelay: .seconds(0)
        )

        await viewModel.startIfNeeded()

        let initialClient = try XCTUnwrap(streamFactory.createdClients.first)
        initialClient.sendMessage(
            ProtectedSessionStreamMessageDTO(
                type: "subscribed",
                session_id: "session-1",
                stream_sequence: 1,
                content_revision: 1,
                state: apiClient.createdState,
                resumed: true,
                source_action_id: nil,
                client_action_id: nil,
                action_status: nil,
                code: nil,
                message: nil,
                worker_state: nil,
                worker_health: nil,
                dropped_events: nil
            )
        )
        XCTAssertEqual(viewModel.clientState, .live)

        initialClient.disconnectWithError(URLError(.networkConnectionLost))
        XCTAssertEqual(viewModel.clientState, .reconnecting(attempt: 1))

        await Task.yield()
        await Task.yield()

        let reconnectClientOne = try XCTUnwrap(streamFactory.createdClients.dropFirst().first)
        reconnectClientOne.disconnectWithError(URLError(.networkConnectionLost))
        XCTAssertEqual(viewModel.clientState, .reconnecting(attempt: 2))

        await Task.yield()
        await Task.yield()

        let reconnectClientTwo = try XCTUnwrap(streamFactory.createdClients.dropFirst(2).first)
        reconnectClientTwo.disconnectWithError(URLError(.networkConnectionLost))

        XCTAssertEqual(viewModel.clientState, .degradedPolling)
        XCTAssertEqual(viewModel.streamStatusLabel, "Polling fallback")
    }

    func testRefreshExpiredStateBecomesExplicitTerminalState() async {
        let apiClient = ProtectedSessionAPIClientStub()
        apiClient.refreshedState = ProtectedSessionStateDTO(
            session_id: "session-1",
            status: "expired",
            allowed_host: "example.com",
            started_at: Date(),
            expires_at: Date().addingTimeInterval(-10),
            last_activity_at: Date().addingTimeInterval(-30),
            can_go_back: false,
            can_go_forward: false,
            content_revision: 2,
            runtime_kind: "visual_stream_session",
            stream_transport: "websocket",
            worker_id: "worker-1",
            worker_type: "visual_stream_session",
            worker_state: "closed",
            worker_health: "ok",
            current_frame: nil,
            current_page: nil,
            detail_message: "That protected session expired and was cleared remotely."
        )

        let viewModel = ProtectedSessionViewModel(
            url: URL(string: "https://example.com")!,
            apiClient: apiClient,
            streamClientFactory: FakeProtectedSessionStreamClientFactory(),
            reconnectDelay: .seconds(0)
        )

        await viewModel.startIfNeeded()
        await viewModel.refresh()

        XCTAssertEqual(viewModel.clientState, .expired)
        XCTAssertEqual(viewModel.sessionStatusTitle, "Expired")
        XCTAssertTrue(viewModel.terminalStateMessage.contains("expired"))
    }

    func testActionsUseRestFallbackWhenLiveStreamIsUnavailable() async {
        let apiClient = ProtectedSessionAPIClientStub()
        apiClient.makeStreamRequestError = AmonAPIError.invalidURL

        let viewModel = ProtectedSessionViewModel(
            url: URL(string: "https://example.com")!,
            apiClient: apiClient,
            streamClientFactory: FakeProtectedSessionStreamClientFactory(),
            reconnectDelay: .seconds(0)
        )

        await viewModel.startIfNeeded()
        await viewModel.reload()

        XCTAssertEqual(apiClient.sentActions.map(\.action), [.reload])
        XCTAssertEqual(viewModel.actionState, .idle)
        XCTAssertEqual(viewModel.clientState, .degradedPolling)
    }

    func testActionFailureWhileSessionLivesUsesActionSpecificBannerTitle() async {
        let apiClient = ProtectedSessionAPIClientStub()
        apiClient.makeStreamRequestError = AmonAPIError.invalidURL
        apiClient.actionError = AmonAPIError.serverError(
            AmonBackendErrorContext(
                statusCode: 409,
                code: "protected_session_navigation_blocked",
                message: "That remote session is limited to its original host in this build."
            )
        )

        let viewModel = ProtectedSessionViewModel(
            url: URL(string: "https://example.com")!,
            apiClient: apiClient,
            streamClientFactory: FakeProtectedSessionStreamClientFactory(),
            reconnectDelay: .seconds(0)
        )

        await viewModel.startIfNeeded()
        await viewModel.navigate(to: "https://other.example.com")

        XCTAssertEqual(viewModel.clientState, .degradedPolling)
        XCTAssertEqual(viewModel.banner?.title, "Couldn't complete remote action")
        XCTAssertEqual(viewModel.banner?.message, "That remote session is limited to its original host in this build.")
    }

    func testClosedActionErrorTransitionsToEndedState() async {
        let apiClient = ProtectedSessionAPIClientStub()
        apiClient.makeStreamRequestError = AmonAPIError.invalidURL
        apiClient.actionError = AmonAPIError.serverError(
            AmonBackendErrorContext(
                statusCode: 410,
                code: "protected_session_closed",
                message: "That protected session was closed and its remote state was destroyed."
            )
        )

        let viewModel = ProtectedSessionViewModel(
            url: URL(string: "https://example.com")!,
            apiClient: apiClient,
            streamClientFactory: FakeProtectedSessionStreamClientFactory(),
            reconnectDelay: .seconds(0)
        )

        await viewModel.startIfNeeded()
        await viewModel.reload()

        XCTAssertEqual(viewModel.clientState, .ended)
        XCTAssertEqual(viewModel.terminalStateTitle, "Protected Session ended")
        XCTAssertTrue(viewModel.terminalStateMessage.contains("closed"))
    }
}

private final class ProtectedSessionAPIClientStub: AmonAPIClienting, @unchecked Sendable {
    var createdState = ProtectedSessionStateDTO(
        session_id: "session-1",
        status: "active",
        allowed_host: "example.com",
        started_at: Date(),
        expires_at: Date().addingTimeInterval(300),
        last_activity_at: Date(),
        can_go_back: false,
        can_go_forward: false,
        content_revision: 1,
        runtime_kind: "visual_stream_session",
        stream_transport: "websocket",
        worker_id: "worker-1",
        worker_type: "visual_stream_session",
        worker_state: "ready",
        worker_health: "ok",
        current_frame: nil,
        current_page: ProtectedSessionPageDTO(
            url: "https://example.com",
            title: "Example",
            domain: "example.com",
            excerpt: "Example excerpt",
            text_blocks: [],
            links: [],
            forms: [],
            fetched_at: Date()
        ),
        detail_message: nil
    )
    var refreshedState: ProtectedSessionStateDTO?
    var createSessionError: Error?
    var makeStreamRequestError: Error?
    var sessionStateError: Error?
    var actionError: Error?
    var sentActions: [ProtectedSessionActionRequestDTO] = []

    func devLogin(appleSubject: String) async throws -> AuthResponseDTO { throw stubError }
    func me() async throws -> UserDTO { throw stubError }
    func search(query: String, count: Int) async throws -> [SearchResult] { throw stubError }
    func retrieve(url: String) async throws -> StructuredRetrievalDTO { throw stubError }
    func serveDecision(url: String, intent: ServeDecisionIntentDTO) async throws -> ServeDecisionResponseDTO { throw stubError }

    func createProtectedSession(url: String) async throws -> ProtectedSessionStateDTO {
        if let createSessionError {
            throw createSessionError
        }
        return createdState
    }

    func makeProtectedSessionStreamRequest(sessionID: String) throws -> URLRequest {
        if let makeStreamRequestError {
            throw makeStreamRequestError
        }
        return URLRequest(url: URL(string: "wss://example.com/protected")!)
    }

    func getProtectedSessionState(sessionID: String) async throws -> ProtectedSessionStateDTO {
        if let sessionStateError {
            throw sessionStateError
        }
        return refreshedState ?? createdState
    }

    func sendProtectedSessionAction(
        sessionID: String,
        action: ProtectedSessionActionRequestDTO
    ) async throws -> ProtectedSessionStateDTO {
        if let actionError {
            throw actionError
        }
        sentActions.append(action)
        return createdState
    }

    func endProtectedSession(sessionID: String) async throws -> ProtectedSessionEndResponseDTO {
        ProtectedSessionEndResponseDTO(session_id: sessionID, status: "ended")
    }

    func compare(title: String, items: [Item]) async throws -> CompareResponseDTO { throw stubError }
    func research(title: String, promptContext: String?, items: [Item]) async throws -> ResearchResponseDTO { throw stubError }
    func clearSession() throws {}

    private var stubError: Error {
        NSError(domain: "ProtectedSessionAPIClientStub", code: -1)
    }
}

private final class FakeProtectedSessionStreamClientFactory: ProtectedSessionStreamClientBuilding, @unchecked Sendable {
    private(set) var createdClients: [FakeProtectedSessionStreamClient] = []

    func make(
        request: URLRequest,
        onMessage: @escaping @Sendable (ProtectedSessionStreamMessageDTO) -> Void,
        onDisconnect: @escaping @Sendable (Error?) -> Void
    ) -> any ProtectedSessionStreamConnecting {
        let client = FakeProtectedSessionStreamClient(onMessage: onMessage, onDisconnect: onDisconnect)
        createdClients.append(client)
        return client
    }
}

private final class FakeProtectedSessionStreamClient: ProtectedSessionStreamConnecting, @unchecked Sendable {
    private let onMessage: @Sendable (ProtectedSessionStreamMessageDTO) -> Void
    private let onDisconnect: @Sendable (Error?) -> Void
    private(set) var lastConnectedSequence: Int?

    init(
        onMessage: @escaping @Sendable (ProtectedSessionStreamMessageDTO) -> Void,
        onDisconnect: @escaping @Sendable (Error?) -> Void
    ) {
        self.onMessage = onMessage
        self.onDisconnect = onDisconnect
    }

    func connect(lastStreamSequence: Int?) {
        lastConnectedSequence = lastStreamSequence
    }

    func disconnect() {}

    func sendAction(
        action: ProtectedSessionActionRequestDTO,
        clientActionID: String,
        expectedContentRevision: Int?
    ) async throws {}

    func sendMessage(_ message: ProtectedSessionStreamMessageDTO) {
        onMessage(message)
    }

    func disconnectWithError(_ error: Error?) {
        onDisconnect(error)
    }
}
