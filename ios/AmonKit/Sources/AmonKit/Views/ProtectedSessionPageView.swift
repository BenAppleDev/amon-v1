import SwiftUI

public struct ProtectedSessionPageView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ProtectedSessionViewModel
    private let initialTitle: String
    private let initialURL: URL
    @State private var navigationAddress = ""

    public init(title: String, url: URL, apiClient: any AmonAPIClienting) {
        self.initialTitle = title
        self.initialURL = url
        _viewModel = StateObject(wrappedValue: ProtectedSessionViewModel(url: url, apiClient: apiClient))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                AmonTrustStripView(
                    items: [
                        "Protected Session",
                        "Remote ephemeral state",
                        viewModel.allowedHost,
                    ]
                )

                if let banner = viewModel.banner {
                    AmonBannerView(banner: banner, dismiss: viewModel.dismissBanner)
                }

                sessionStatusCard

                if viewModel.canDisplayLiveSessionSurface {
                    if viewModel.shouldShowInteractiveControls {
                        remoteControls
                    }

                    if let frame = viewModel.currentFrame {
                        snapshotCard(frame)
                    } else if viewModel.isAwaitingFirstFrame {
                        snapshotPlaceholderCard
                    }

                    if let page = viewModel.currentPage {
                        pageSummary(page)

                        if let excerpt = page.excerpt, !excerpt.isEmpty {
                            detailCard(title: "Remote summary", body: excerpt)
                        }

                        if !page.links.isEmpty {
                            linksCard(page.links)
                        }

                        if !page.forms.isEmpty {
                            formsCard(page.forms)
                        }
                    }
                } else if viewModel.isStartingSession {
                    AmonEmptyStateView(
                        title: "Starting Protected Session",
                        message: "Amon is opening a remote site session and preparing its first snapshot.",
                        systemImage: "lock.shield"
                    )
                } else if case .expired = viewModel.clientState {
                    AmonEmptyStateView(
                        title: viewModel.terminalStateTitle,
                        message: viewModel.terminalStateMessage,
                        systemImage: "hourglass.badge.exclamationmark"
                    )
                } else if case .ended = viewModel.clientState {
                    AmonEmptyStateView(
                        title: viewModel.terminalStateTitle,
                        message: viewModel.terminalStateMessage,
                        systemImage: "xmark.circle"
                    )
                } else if case .failed = viewModel.clientState {
                    AmonEmptyStateView(
                        title: viewModel.terminalStateTitle,
                        message: viewModel.terminalStateMessage,
                        systemImage: {
                            if case .some(.unavailable) = viewModel.failurePresentation {
                                return "lock.slash"
                            }
                            return "exclamationmark.triangle"
                        }()
                    )
                } else {
                    AmonEmptyStateView(
                        title: "Protected Session unavailable",
                        message: "Amon couldn't open a remote session for that page.",
                        systemImage: "exclamationmark.triangle"
                    )
                }

                Button(role: .destructive) {
                    Task {
                        if await viewModel.endSession() {
                            dismiss()
                        }
                    }
                } label: {
                    HStack {
                        if viewModel.isEndingSession {
                            ProgressView()
                                .progressViewStyle(.circular)
                        }
                        Label("End Session", systemImage: "xmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(viewModel.isEndingSession)
            }
            .padding(20)
        }
        .background(AmonTheme.canvas.ignoresSafeArea())
        .navigationTitle(viewModel.currentPage?.title ?? initialTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            navigationAddress = initialURL.absoluteString
            await viewModel.startIfNeeded()
            navigationAddress = viewModel.currentPage?.url ?? initialURL.absoluteString
        }
        .onChange(of: viewModel.currentPage?.url) { _, newValue in
            if let newValue {
                navigationAddress = newValue
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    private var sessionStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Remote session status")
                .font(.headline)

            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                    .padding(.top, 6)

                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.sessionStatusTitle)
                        .font(.subheadline.weight(.semibold))
                    Text(viewModel.sessionStatusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Worker: \(viewModel.state?.worker_type ?? "visual_stream_session") · Stream: \(viewModel.streamStatusLabel)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if let actionMessage = viewModel.actionStatusMessage {
                        Text(actionMessage)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    if let state = viewModel.state {
                        Text("Expires \(AmonFormatters.relativeTimestamp(for: state.expires_at))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .amonCardStyle()
    }

    private var statusColor: Color {
        switch viewModel.clientState {
        case .live:
            return Color(uiColor: .systemGreen)
        case .reconnecting, .degradedPolling, .connecting:
            return Color(uiColor: .systemOrange)
        case .ended, .expired:
            return Color(uiColor: .systemGray)
        case .failed:
            return Color(uiColor: .systemRed)
        }
    }

    private var remoteControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Remote controls")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Button {
                        Task { await viewModel.goBack() }
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!(viewModel.state?.can_go_back ?? false) || viewModel.isPerformingAction || !viewModel.canInteract)

                    Button {
                        Task { await viewModel.goForward() }
                    } label: {
                        Label("Forward", systemImage: "chevron.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!(viewModel.state?.can_go_forward ?? false) || viewModel.isPerformingAction || !viewModel.canInteract)

                    Button {
                        Task { await viewModel.reload() }
                    } label: {
                        Label("Reload", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isPerformingAction || !viewModel.canInteract)
                }

                HStack(spacing: 12) {
                    TextField("https://\(viewModel.allowedHost)/...", text: $navigationAddress)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(AmonTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(AmonTheme.border.opacity(0.85), lineWidth: 1)
                        )

                    Button("Go") {
                        Task { await viewModel.navigate(to: navigationAddress) }
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isPerformingAction || !viewModel.canInteract || navigationAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .amonCardStyle()
    }

    private var snapshotPlaceholderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Remote visual snapshot")
                .font(.headline)

            AmonEmptyStateView(
                title: "Preparing first snapshot",
                message: "The protected session is live, but Amon is still waiting for the first remote frame.",
                systemImage: "photo.on.rectangle.angled"
            )
        }
        .amonCardStyle()
    }

    private func pageSummary(_ page: ProtectedSessionPageDTO) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(page.title)
                .font(.title3.weight(.semibold))
            Text(page.domain)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(page.url)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .amonCardStyle()
    }

    private func detailCard(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            Text(body)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .amonCardStyle()
    }

    private func snapshotCard(_ frame: ProtectedSessionFrameDTO) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Remote visual snapshot")
                .font(.headline)

            ProtectedSessionSnapshotView(svgDocument: frame.document)
                .frame(maxWidth: .infinity)
                .frame(height: 520)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            Text("Frame \(frame.revision) · \(AmonFormatters.relativeTimestamp(for: frame.generated_at))")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .amonCardStyle()
    }

    private func textBlocksCard(_ blocks: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Visible remote text")
                .font(.headline)

            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                Text(block)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .amonCardStyle()
    }

    private func linksCard(_ links: [ProtectedSessionLinkDTO]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Remote action targets")
                .font(.headline)

            ForEach(links, id: \.id) { link in
                Button {
                    Task { await viewModel.open(link: link) }
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(link.label)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(link.url)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isPerformingAction || !viewModel.canInteract)
            }
        }
        .amonCardStyle()
    }

    private func formsCard(_ forms: [ProtectedSessionFormDTO]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Remote forms")
                .font(.headline)

            ForEach(forms, id: \.id) { form in
                VStack(alignment: .leading, spacing: 12) {
                    Text(form.submit_label)
                        .font(.subheadline.weight(.semibold))

                    ForEach(form.fields, id: \.name) { field in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(field.label)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                            fieldInput(field, formID: form.id)
                        }
                    }

                    Button {
                        Task { await viewModel.submit(form: form) }
                    } label: {
                        Label(form.submit_label, systemImage: "paperplane")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isPerformingAction || !viewModel.canInteract)
                }
                .padding(16)
                .background(AmonTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
        .amonCardStyle()
    }

    @ViewBuilder
    private func fieldInput(_ field: ProtectedSessionFieldDTO, formID: String) -> some View {
        if field.field_type == "password" {
            SecureField(
                field.placeholder ?? field.label,
                text: Binding(
                    get: { viewModel.draftValue(for: field, formID: formID) },
                    set: { viewModel.updateDraft($0, for: field, formID: formID) }
                )
            )
            .textInputAutocapitalization(.never)
            .disableAutocorrection(true)
            .disabled(viewModel.isPerformingAction || !viewModel.canInteract)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AmonTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
            TextField(
                field.placeholder ?? field.label,
                text: Binding(
                    get: { viewModel.draftValue(for: field, formID: formID) },
                    set: { viewModel.updateDraft($0, for: field, formID: formID) }
                )
            )
            .textInputAutocapitalization(.never)
            .disableAutocorrection(true)
            .disabled(viewModel.isPerformingAction || !viewModel.canInteract)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AmonTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}
