import Foundation

@MainActor
public final class ProtectedSessionViewModel: ObservableObject {
    @Published public private(set) var state: ProtectedSessionStateDTO?
    @Published public private(set) var isLoading = false
    @Published public private(set) var isEndingSession = false
    @Published public private(set) var streamConnectionState = "connecting"
    @Published var banner: AmonBanner?
    @Published private var fieldDrafts: [String: String] = [:]

    private let initialURL: URL
    private let apiClient: any AmonAPIClienting
    private var didStart = false
    private var pollingTask: Task<Void, Never>?
    private var streamClient: ProtectedSessionStreamClient?
    private var reconnectTask: Task<Void, Never>?
    private var pendingStreamActionID: String?
    private var pendingActionBaseRevision: Int?
    private var lastStreamSequence = 0
    private var reconnectAttempts = 0

    public init(url: URL, apiClient: any AmonAPIClienting) {
        self.initialURL = url
        self.apiClient = apiClient
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

    public func startIfNeeded() async {
        guard !didStart else { return }
        didStart = true
        isLoading = true
        defer { isLoading = false }

        do {
            let created = try await apiClient.createProtectedSession(url: initialURL.absoluteString)
            apply(state: created)
            connectStream(for: created.session_id, resumeFromSequence: nil)
            beginPolling()
        } catch {
            didStart = false
            banner = AmonBanner(
                tone: .error,
                title: "Protected Session unavailable",
                message: AmonErrorPresenter.message(
                    for: error,
                    fallback: "Amon couldn't start a protected session for that page."
                )
            )
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
            pendingStreamActionID = nil
            pendingActionBaseRevision = nil
            streamConnectionState = "closed"
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
        guard let sessionID else { return false }
        isLoading = true

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
                pendingStreamActionID = nil
                pendingActionBaseRevision = nil
                isLoading = false
                handleSessionError(error, fallback: fallback)
                return false
            }
        }

        defer { isLoading = false }
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
        if state.stream_transport == "websocket" {
            streamConnectionState = "live"
        }
        if let pendingStreamActionID,
           let baseRevision = pendingActionBaseRevision,
           state.content_revision > baseRevision {
            self.pendingStreamActionID = nil
            self.pendingActionBaseRevision = nil
            isLoading = false
        }
        if let detailMessage = state.detail_message, !detailMessage.isEmpty {
            banner = AmonBanner(tone: .info, title: "Protected Session", message: detailMessage)
        }
        seedDrafts(from: state.current_page)
        if ["closed", "expired", "failed"].contains(state.status) {
            streamClient?.disconnect()
            streamClient = nil
            reconnectTask?.cancel()
            reconnectTask = nil
            pendingStreamActionID = nil
            pendingActionBaseRevision = nil
            isLoading = false
            streamConnectionState = state.status
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
        let message = AmonErrorPresenter.message(for: error, fallback: fallback)
        banner = AmonBanner(tone: .error, title: "Protected Session", message: message)
        if message.localizedCaseInsensitiveContains("expired")
            || message.localizedCaseInsensitiveContains("no longer available") {
            pollingTask?.cancel()
            reconnectTask?.cancel()
            streamClient?.disconnect()
            streamClient = nil
            state = nil
            fieldDrafts = [:]
            pendingStreamActionID = nil
            pendingActionBaseRevision = nil
            isLoading = false
            streamConnectionState = "closed"
        }
    }

    private func connectStream(for sessionID: String, resumeFromSequence: Int?) {
        do {
            let request = try apiClient.makeProtectedSessionStreamRequest(sessionID: sessionID)
            let client = ProtectedSessionStreamClient(
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
            streamConnectionState = "connecting"
            client.connect(lastStreamSequence: resumeFromSequence)
        } catch {
            streamConnectionState = "unavailable"
        }
    }

    private func handleStreamMessage(_ message: ProtectedSessionStreamMessageDTO) {
        lastStreamSequence = max(lastStreamSequence, message.stream_sequence)
        if let workerState = message.worker_state, !workerState.isEmpty {
            streamConnectionState = workerState
        }

        switch message.type {
        case "subscribed":
            reconnectAttempts = 0
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
        case "state":
            if let nextState = message.state {
                apply(state: nextState)
            }
            if let sourceActionID = message.source_action_id, sourceActionID == pendingStreamActionID {
                pendingStreamActionID = nil
                pendingActionBaseRevision = nil
                isLoading = false
            }
            if let dropped = message.dropped_events, dropped > 0 {
                banner = AmonBanner(
                    tone: .info,
                    title: "Protected Session",
                    message: "Amon skipped \(dropped) stale remote updates and kept the newest live snapshot."
                )
            }
        case "terminal":
            if let nextState = message.state {
                apply(state: nextState)
            }
            pendingStreamActionID = nil
            isLoading = false
            streamClient?.disconnect()
            streamClient = nil
        case "heartbeat":
            streamConnectionState = "attached"
        case "action_ack":
            if let clientActionID = message.client_action_id,
               clientActionID == pendingStreamActionID,
               message.action_status == "failed" || message.action_status == "rejected" {
                pendingStreamActionID = nil
                pendingActionBaseRevision = nil
                isLoading = false
                banner = AmonBanner(
                    tone: .error,
                    title: "Protected Session",
                    message: message.message ?? "That protected-session action could not be completed."
                )
            }
        case "error":
            banner = AmonBanner(
                tone: .error,
                title: "Protected Session",
                message: message.message ?? "That protected-session stream message was rejected."
            )
        default:
            break
        }
    }

    private func handleStreamDisconnect(_ error: Error?) {
        guard !isEndingSession else { return }
        streamConnectionState = "disconnected"
        guard let sessionID else { return }

        if reconnectAttempts >= 2 {
            if let error {
                banner = AmonBanner(
                    tone: .info,
                    title: "Remote snapshot stream paused",
                    message: AmonErrorPresenter.message(
                        for: error,
                        fallback: "Amon lost the live remote snapshot stream and will keep using periodic session refreshes."
                    )
                )
            }
            return
        }

        reconnectAttempts += 1
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard let self, !Task.isCancelled else { return }
            await MainActor.run {
                self.connectStream(for: sessionID, resumeFromSequence: self.lastStreamSequence)
            }
        }
    }

    private func fieldKey(formID: String, fieldName: String) -> String {
        "\(formID)::\(fieldName)"
    }
}
