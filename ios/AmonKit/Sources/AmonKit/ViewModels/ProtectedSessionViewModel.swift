import Foundation

@MainActor
public final class ProtectedSessionViewModel: ObservableObject {
    @Published public private(set) var state: ProtectedSessionStateDTO?
    @Published public private(set) var sessionLifecycleState: ProtectedSessionLifecycleState = .connecting
    @Published public private(set) var streamState: ProtectedSessionStreamState = .connecting
    @Published public private(set) var actionState: ProtectedSessionActionState = .idle
    @Published public private(set) var failurePresentation: ProtectedSessionFailurePresentation?
    @Published public private(set) var isEndingSession = false
    @Published var banner: AmonBanner?
    @Published private var fieldDrafts: [String: String] = [:]

    private let initialURL: URL
    private let apiClient: any AmonAPIClienting
    private let streamClientFactory: any ProtectedSessionStreamClientBuilding
    private let reconnectDelay: Duration
    private var didStart = false
    private var pollingTask: Task<Void, Never>?
    private var streamClient: (any ProtectedSessionStreamConnecting)?
    private var reconnectTask: Task<Void, Never>?
    private var pendingStreamActionID: String?
    private var pendingActionBaseRevision: Int?
    private var lastStreamSequence = 0
    private var reconnectAttempts = 0

    public init(url: URL, apiClient: any AmonAPIClienting) {
        self.init(
            url: url,
            apiClient: apiClient,
            streamClientFactory: DefaultProtectedSessionStreamClientFactory(),
            reconnectDelay: .seconds(2)
        )
    }

    init(
        url: URL,
        apiClient: any AmonAPIClienting,
        streamClientFactory: any ProtectedSessionStreamClientBuilding,
        reconnectDelay: Duration
    ) {
        self.initialURL = url
        self.apiClient = apiClient
        self.streamClientFactory = streamClientFactory
        self.reconnectDelay = reconnectDelay
    }

    deinit {
        pollingTask?.cancel()
        reconnectTask?.cancel()
        streamClient?.disconnect()
    }

    public var sessionID: String? {
        state?.session_id
    }

    public var navigationTitle: String {
        state?.current_page?.title ?? "Protected Session"
    }

    public var allowedHost: String {
        state?.allowed_host ?? initialURL.host ?? initialURL.absoluteString
    }

    public var currentPage: ProtectedSessionPageDTO? {
        state?.current_page
    }

    public var currentFrame: ProtectedSessionFrameDTO? {
        state?.current_frame
    }

    public var clientState: ProtectedSessionClientState {
        switch sessionLifecycleState {
        case .connecting:
            return .connecting
        case .expired:
            return .expired
        case .ended:
            return .ended
        case .failed:
            return .failed
        case .live:
            switch streamState {
            case .connecting:
                return .connecting
            case .live:
                return .live
            case .reconnecting(let attempt):
                return .reconnecting(attempt: attempt)
            case .degradedPolling:
                return .degradedPolling
            }
        }
    }

    public var canInteract: Bool {
        if case .live = sessionLifecycleState {
            return !isEndingSession
        }
        return false
    }

    public var isPerformingAction: Bool {
        actionState.isPerforming
    }

    public var isStartingSession: Bool {
        if case .connecting = sessionLifecycleState {
            return state == nil
        }
        return false
    }

    public var isAwaitingFirstFrame: Bool {
        guard canDisplayLiveSessionSurface else { return false }
        return currentFrame == nil
    }

    public var canDisplayLiveSessionSurface: Bool {
        switch sessionLifecycleState {
        case .live, .expired, .ended, .failed:
            return state != nil
        case .connecting:
            return false
        }
    }

    public var shouldShowInteractiveControls: Bool {
        canInteract && state != nil && clientState != .connecting
    }

    private var effectiveFailurePresentation: ProtectedSessionFailurePresentation? {
        if let failurePresentation {
            return failurePresentation
        }
        if case .failed(let message) = sessionLifecycleState {
            return .failed(message: message ?? "Amon couldn't keep this protected session running.")
        }
        return nil
    }

    public var sessionStatusTitle: String {
        switch clientState {
        case .connecting:
            return "Connecting"
        case .live:
            return "Live"
        case .reconnecting:
            return "Reconnecting"
        case .degradedPolling:
            return "Live with fallback"
        case .expired:
            return "Expired"
        case .ended:
            return "Ended"
        case .failed:
            return effectiveFailurePresentation?.sessionStatusTitle ?? "Failed"
        }
    }

    public var sessionStatusMessage: String {
        switch clientState {
        case .connecting:
            return "Amon is opening the remote session and preparing the first protected snapshot for \(allowedHost)."
        case .live:
            return "Remote state is live for \(allowedHost). The session will expire unless you keep interacting."
        case .reconnecting(let attempt):
            return "Amon is reconnecting the live snapshot stream for \(allowedHost). Attempt \(attempt) of 2."
        case .degradedPolling:
            return streamFallbackMessage ?? "The live snapshot stream is degraded. Amon is keeping the session alive with periodic refreshes."
        case .expired:
            if case .expired(let message) = sessionLifecycleState {
                return message ?? "This protected session expired and its remote state is no longer available."
            }
            return "This protected session expired and its remote state is no longer available."
        case .ended:
            if case .ended(let message) = sessionLifecycleState {
                return message ?? "This protected session ended and won't accept new actions."
            }
            return "This protected session ended and won't accept new actions."
        case .failed:
            return effectiveFailurePresentation?.message
                ?? "Amon couldn't keep this protected session running."
        }
    }

    public var streamStatusLabel: String {
        switch streamState {
        case .connecting:
            return "Connecting"
        case .live:
            return "Live"
        case .reconnecting(let attempt):
            return "Reconnecting (\(attempt))"
        case .degradedPolling:
            return "Polling fallback"
        }
    }

    public var actionStatusMessage: String? {
        guard case .performing(let action) = actionState else { return nil }
        switch action {
        case .reload:
            return "Reloading remote page…"
        case .back:
            return "Going back…"
        case .forward:
            return "Going forward…"
        case .clickLink:
            return "Opening remote link…"
        case .updateField:
            return "Updating remote form…"
        case .submitForm:
            return "Submitting remote form…"
        case .navigateToURL:
            return "Opening remote address…"
        }
    }

    public var terminalStateTitle: String {
        switch clientState {
        case .expired:
            return "Protected Session expired"
        case .ended:
            return "Protected Session ended"
        case .failed:
            return effectiveFailurePresentation?.terminalTitle ?? "Protected Session unavailable"
        default:
            return "Protected Session"
        }
    }

    public var terminalStateMessage: String {
        switch clientState {
        case .expired, .ended, .failed:
            return sessionStatusMessage
        default:
            return "Amon couldn't keep that protected session available."
        }
    }

    private var streamFallbackMessage: String? {
        if case .degradedPolling(let message) = streamState {
            return message
        }
        return nil
    }

    public func startIfNeeded() async {
        guard !didStart else { return }
        didStart = true
        sessionLifecycleState = .connecting
        streamState = .connecting
        actionState = .idle
        failurePresentation = nil

        do {
            let created = try await apiClient.createProtectedSession(url: initialURL.absoluteString)
            apply(state: created)
            connectStream(for: created.session_id, resumeFromSequence: nil)
            beginPolling()
        } catch {
            didStart = false
            let fallback = "Amon couldn't start a protected session for that page."
            let presentation = AmonErrorPresenter.protectedSessionFailurePresentation(
                for: error,
                fallback: fallback
            )
            let message = presentation?.message
                ?? AmonErrorPresenter.message(for: error, fallback: fallback)
            failurePresentation = presentation ?? .failed(message: message)
            sessionLifecycleState = .failed(message: message)
            streamState = .degradedPolling(message: nil)
            actionState = .idle
            banner = nil
        }
    }

    public func refresh() async {
        guard let sessionID else { return }
        do {
            let updated = try await apiClient.getProtectedSessionState(sessionID: sessionID)
            apply(state: updated)
        } catch {
            handleSessionError(
                error,
                fallback: "Amon couldn't refresh that protected session."
            )
        }
    }

    public func reload() async {
        await perform(
            action: ProtectedSessionActionRequestDTO(action: .reload),
            fallback: "Amon couldn't reload that protected session page."
        )
    }

    public func goBack() async {
        await perform(
            action: ProtectedSessionActionRequestDTO(action: .back),
            fallback: "Amon couldn't move back in that protected session."
        )
    }

    public func goForward() async {
        await perform(
            action: ProtectedSessionActionRequestDTO(action: .forward),
            fallback: "Amon couldn't move forward in that protected session."
        )
    }

    public func open(link: ProtectedSessionLinkDTO) async {
        await perform(
            action: ProtectedSessionActionRequestDTO(action: .clickLink, link_id: link.id),
            fallback: "Amon couldn't open that remote link."
        )
    }

    public func navigate(to rawURL: String) async {
        await perform(
            action: ProtectedSessionActionRequestDTO(action: .navigateToURL, url: rawURL),
            fallback: "Amon couldn't open that URL in the protected session."
        )
    }

    public func draftValue(for field: ProtectedSessionFieldDTO, formID: String) -> String {
        fieldDrafts[fieldKey(formID: formID, fieldName: field.name)] ?? field.value ?? ""
    }

    public func updateDraft(_ value: String, for field: ProtectedSessionFieldDTO, formID: String) {
        fieldDrafts[fieldKey(formID: formID, fieldName: field.name)] = value
    }

    public func submit(form: ProtectedSessionFormDTO) async {
        for field in form.fields {
            let updatedValue = draftValue(for: field, formID: form.id)
            if updatedValue != (field.value ?? "") {
                let ok = await perform(
                    action: ProtectedSessionActionRequestDTO(
                        action: .updateField,
                        form_id: form.id,
                        field_name: field.name,
                        value: updatedValue
                    ),
                    fallback: "Amon couldn't update that protected-session field."
                )
                if !ok { return }
            }
        }

        _ = await perform(
            action: ProtectedSessionActionRequestDTO(action: .submitForm, form_id: form.id),
            fallback: "Amon couldn't submit that protected-session form."
        )
    }

    @discardableResult
    public func endSession() async -> Bool {
        guard let sessionID else { return true }
        pollingTask?.cancel()
        reconnectTask?.cancel()
        streamClient?.disconnect()
        streamClient = nil
        isEndingSession = true
        defer { isEndingSession = false }

        do {
            _ = try await apiClient.endProtectedSession(sessionID: sessionID)
            state = nil
            fieldDrafts = [:]
            banner = nil
            failurePresentation = nil
            pendingStreamActionID = nil
            pendingActionBaseRevision = nil
            actionState = .idle
            sessionLifecycleState = .ended(message: "This protected session ended and its remote state was destroyed.")
            streamState = .degradedPolling(message: nil)
            return true
        } catch {
            banner = AmonBanner(
                tone: .error,
                title: "Couldn't end protected session",
                message: AmonErrorPresenter.message(
                    for: error,
                    fallback: "Amon couldn't end that protected session cleanly."
                )
            )
            return false
        }
    }

    public func dismissBanner() {
        banner = nil
    }

    @discardableResult
    private func perform(action: ProtectedSessionActionRequestDTO, fallback: String) async -> Bool {
        guard let sessionID, canInteract else { return false }
        actionState = .performing(action.action)

        if let streamClient {
            let actionID = UUID().uuidString
            pendingStreamActionID = actionID
            pendingActionBaseRevision = state?.content_revision
            do {
                try await streamClient.sendAction(
                    action: action,
                    clientActionID: actionID,
                    expectedContentRevision: state?.content_revision
                )
                return true
            } catch {
                clearPendingAction()
                handleSessionError(error, fallback: fallback)
                return false
            }
        }

        defer { actionState = .idle }
        do {
            let updated = try await apiClient.sendProtectedSessionAction(sessionID: sessionID, action: action)
            apply(state: updated)
            return true
        } catch {
            handleSessionError(error, fallback: fallback)
            return false
        }
    }

    private func beginPolling() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20))
                guard !Task.isCancelled else { break }
                await self.refresh()
            }
        }
    }

    private func apply(state: ProtectedSessionStateDTO) {
        self.state = state
        sessionLifecycleState = lifecycleState(from: state)
        seedDrafts(from: state.current_page)

        switch sessionLifecycleState {
        case .failed(let message):
            failurePresentation = .failed(
                message: message ?? "Amon couldn't keep this protected session running."
            )
        case .connecting, .live, .expired, .ended:
            failurePresentation = nil
        }

        if let pendingStreamActionID,
           let baseRevision = pendingActionBaseRevision,
           state.content_revision > baseRevision {
            clearPendingAction()
        }

        if state.isTerminalStatus || isTerminalLifecycleState {
            streamClient?.disconnect()
            streamClient = nil
            reconnectTask?.cancel()
            reconnectTask = nil
            clearPendingAction()
        } else if streamClient == nil {
            streamState = .degradedPolling(message: streamFallbackMessage)
        }

        if let detailMessage = state.detail_message, !detailMessage.isEmpty, !isTerminalLifecycleState {
            banner = AmonBanner(tone: .info, title: "Protected Session", message: detailMessage)
        }
    }

    private var isTerminalLifecycleState: Bool {
        switch sessionLifecycleState {
        case .expired, .ended, .failed:
            return true
        case .connecting, .live:
            return false
        }
    }

    private func lifecycleState(from state: ProtectedSessionStateDTO) -> ProtectedSessionLifecycleState {
        let message = state.detail_message?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? state.detail_message
            : nil

        switch state.backendStatus {
        case .creating, nil:
            return .connecting
        case .active:
            return .live
        case .terminating, .closed:
            return .ended(message: message ?? "This protected session is ending and won't accept new actions.")
        case .expired:
            return .expired(message: message ?? "That protected session expired and its remote state was cleared.")
        case .failed:
            return .failed(message: message ?? "Amon couldn't keep that protected session running.")
        }
    }

    private func seedDrafts(from page: ProtectedSessionPageDTO?) {
        guard let page else { return }
        var nextDrafts: [String: String] = [:]
        for form in page.forms {
            for field in form.fields {
                nextDrafts[fieldKey(formID: form.id, fieldName: field.name)] = field.value ?? ""
            }
        }
        fieldDrafts = nextDrafts
    }

    private func handleSessionError(_ error: Error, fallback: String) {
        clearPendingAction()

        if let terminalState = AmonErrorPresenter.protectedSessionTerminalState(for: error, fallback: fallback) {
            pollingTask?.cancel()
            reconnectTask?.cancel()
            streamClient?.disconnect()
            streamClient = nil
            fieldDrafts = [:]
            failurePresentation = AmonErrorPresenter.protectedSessionFailurePresentation(
                for: error,
                fallback: fallback
            )
            sessionLifecycleState = terminalState
            return
        }

        let message = AmonErrorPresenter.message(for: error, fallback: fallback)
        banner = AmonBanner(
            tone: .error,
            title: AmonErrorPresenter.protectedSessionActionBannerTitle(for: error),
            message: message
        )
    }

    private func connectStream(for sessionID: String, resumeFromSequence: Int?) {
        do {
            let request = try apiClient.makeProtectedSessionStreamRequest(sessionID: sessionID)
            let client = streamClientFactory.make(
                request: request,
                onMessage: { [weak self] message in
                    Task { @MainActor [weak self] in
                        self?.handleStreamMessage(message)
                    }
                },
                onDisconnect: { [weak self] error in
                    Task { @MainActor [weak self] in
                        self?.handleStreamDisconnect(error)
                    }
                }
            )
            streamClient?.disconnect()
            streamClient = client
            streamState = resumeFromSequence == nil ? .connecting : .reconnecting(attempt: max(reconnectAttempts, 1))
            client.connect(lastStreamSequence: resumeFromSequence)
        } catch {
            let message = "Amon couldn't attach the live remote snapshot stream and will keep using periodic session refreshes."
            if case .connecting = sessionLifecycleState, state == nil {
                failurePresentation = .failed(message: message)
                sessionLifecycleState = .failed(message: message)
            }
            streamState = .degradedPolling(message: message)
        }
    }

    private func handleStreamMessage(_ message: ProtectedSessionStreamMessageDTO) {
        lastStreamSequence = max(lastStreamSequence, message.stream_sequence)

        switch message.kind {
        case .subscribed:
            reconnectAttempts = 0
            streamState = .live
            if let nextState = message.state {
                apply(state: nextState)
            }
            if message.resumed == false {
                banner = AmonBanner(
                    tone: .info,
                    title: "Protected Session",
                    message: "Amon resumed the remote session with the latest available snapshot."
                )
            }
        case .state:
            if let nextState = message.state {
                apply(state: nextState)
            }
            if case .live = sessionLifecycleState {
                streamState = .live
            }
            if let sourceActionID = message.source_action_id, sourceActionID == pendingStreamActionID {
                clearPendingAction()
            }
            if let dropped = message.dropped_events, dropped > 0 {
                banner = AmonBanner(
                    tone: .info,
                    title: "Protected Session",
                    message: "Amon skipped \(dropped) stale remote updates and kept the newest live snapshot."
                )
            }
        case .terminal:
            if let nextState = message.state {
                apply(state: nextState)
            } else {
                failurePresentation = nil
                sessionLifecycleState = .ended(message: message.message ?? "This protected session ended remotely.")
            }
            clearPendingAction()
            streamClient?.disconnect()
            streamClient = nil
        case .heartbeat:
            if case .live = sessionLifecycleState {
                streamState = .live
            }
        case .actionAck:
            if let clientActionID = message.client_action_id,
               clientActionID == pendingStreamActionID,
               message.action_status == "failed" || message.action_status == "rejected" {
                clearPendingAction()
                banner = AmonErrorPresenter.protectedSessionActionBanner(
                    code: message.code,
                    message: message.message
                )
            }
        case .error:
            banner = AmonErrorPresenter.protectedSessionActionBanner(
                code: message.code,
                message: message.message ?? "That protected-session stream message was rejected."
            )
        case nil:
            break
        }
    }

    private func handleStreamDisconnect(_ error: Error?) {
        guard !isEndingSession else { return }
        guard !isTerminalLifecycleState else { return }
        guard let sessionID else {
            if let error {
                let fallback = "Amon couldn't attach the protected-session stream."
                failurePresentation = AmonErrorPresenter.protectedSessionFailurePresentation(
                    for: error,
                    fallback: fallback
                ) ?? .failed(message: AmonErrorPresenter.message(for: error, fallback: fallback))
                sessionLifecycleState = .failed(
                    message: AmonErrorPresenter.message(
                        for: error,
                        fallback: fallback
                    )
                )
            }
            return
        }

        if reconnectAttempts >= 2 {
            let message = error.map {
                AmonErrorPresenter.message(
                    for: $0,
                    fallback: "Amon lost the live remote snapshot stream and will keep using periodic session refreshes."
                )
            } ?? "Amon lost the live remote snapshot stream and will keep using periodic session refreshes."
            streamState = .degradedPolling(message: message)
            banner = AmonBanner(
                tone: .info,
                title: "Remote snapshot stream paused",
                message: message
            )
            return
        }

        reconnectAttempts += 1
        streamState = .reconnecting(attempt: reconnectAttempts)
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(for: self?.reconnectDelay ?? .seconds(2))
            guard let self, !Task.isCancelled else { return }
            await MainActor.run {
                self.connectStream(for: sessionID, resumeFromSequence: self.lastStreamSequence)
            }
        }
    }

    private func clearPendingAction() {
        pendingStreamActionID = nil
        pendingActionBaseRevision = nil
        actionState = .idle
    }

    private func fieldKey(formID: String, fieldName: String) -> String {
        "\(formID)::\(fieldName)"
    }
}
