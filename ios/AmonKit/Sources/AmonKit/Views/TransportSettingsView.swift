import SwiftUI

public struct TransportSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store: TransportPrivacySettingsStore
    private let status: TransportTunnelStatusSnapshot
    private let diagnostics: [String]
    private let connectAction: () -> Void
    private let disconnectAction: () -> Void

    public init(
        store: TransportPrivacySettingsStore,
        status: TransportTunnelStatusSnapshot,
        diagnostics: [String],
        connectAction: @escaping () -> Void,
        disconnectAction: @escaping () -> Void
    ) {
        self.store = store
        self.status = status
        self.diagnostics = diagnostics
        self.connectAction = connectAction
        self.disconnectAction = disconnectAction
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AmonTheme.canvas
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        statusSection
                        behaviorSection
                        endpointSection
                        diagnosticsSection
                        limitsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Amon Tunnel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            AmonTrustStripView(
                items: [
                    status.state.title,
                    store.settings.endpoint.displayAddress,
                ]
            )

            Text("This is a transport layer for development. Amon's FastAPI backend stays separate from the tunnel endpoint.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Status")
                .font(.headline)

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)
                        .padding(.top, 6)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(status.state.title)
                            .font(.subheadline.weight(.semibold))
                        Text(status.detail ?? status.state.summary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        connectAction()
                    } label: {
                        Label("Connect", systemImage: "bolt.horizontal.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!store.settings.endpoint.isConfigured || status.state == .connecting || status.state == .connected)

                    Button {
                        disconnectAction()
                    } label: {
                        Label("Disconnect", systemImage: "bolt.slash.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(status.state == .disconnected || status.state == .disconnecting)
                }
            }
            .amonCardStyle()
        }
    }

    private var behaviorSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Behavior")
                .font(.headline)

            VStack(alignment: .leading, spacing: 14) {
                Toggle(isOn: Binding(
                    get: { store.settings.enabledWhenSignedIn },
                    set: { store.updateEnabledWhenSignedIn($0) }
                )) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Connect when signed in")
                            .font(.subheadline.weight(.semibold))
                        Text("When enabled, Amon will try to bring the tunnel up after sign-in.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                Toggle(isOn: Binding(
                    get: { store.settings.autoConnectOnSessionRestore },
                    set: { store.updateAutoConnectOnSessionRestore($0) }
                )) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reconnect after session restore")
                            .font(.subheadline.weight(.semibold))
                        Text("When a saved Amon session comes back, the app will try to reconnect the tunnel automatically.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(!store.settings.enabledWhenSignedIn)
                .opacity(store.settings.enabledWhenSignedIn ? 1 : 0.55)
            }
            .amonCardStyle()
        }
    }

    private var endpointSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Development Endpoint")
                .font(.headline)

            VStack(alignment: .leading, spacing: 14) {
                settingsField(
                    title: "Laptop host",
                    text: Binding(
                        get: { store.settings.endpoint.serverHost },
                        set: { store.updateEndpointHost($0) }
                    ),
                    prompt: "192.168.x.x"
                )

                HStack(spacing: 12) {
                    numericField(
                        title: "Port",
                        value: store.settings.endpoint.serverPort,
                        update: store.updateEndpointPort(_:),
                        prompt: "9443"
                    )

                    numericField(
                        title: "MTU",
                        value: store.settings.endpoint.mtu,
                        update: store.updateMTU(_:),
                        prompt: "1280"
                    )
                }

                HStack(spacing: 12) {
                    settingsField(
                        title: "Client address",
                        text: Binding(
                            get: { store.settings.endpoint.clientAddress },
                            set: { store.updateClientAddress($0) }
                        ),
                        prompt: "10.44.0.2"
                    )

                    settingsField(
                        title: "Remote address",
                        text: Binding(
                            get: { store.settings.endpoint.remoteAddress },
                            set: { store.updateRemoteAddress($0) }
                        ),
                        prompt: "10.44.0.1"
                    )
                }

                settingsField(
                    title: "Subnet mask",
                    text: Binding(
                        get: { store.settings.endpoint.subnetMask },
                        set: { store.updateSubnetMask($0) }
                    ),
                    prompt: "255.255.255.0"
                )

                settingsField(
                    title: "DNS servers",
                    text: Binding(
                        get: { store.dnsServersDisplayValue },
                        set: { store.updateDNSServers($0) }
                    ),
                    prompt: "1.1.1.1, 1.0.0.1"
                )
            }
            .amonCardStyle()
        }
    }

    private var limitsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("MVP Limits")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                Text("This build wires the iPhone app and packet tunnel extension together, but your laptop still has to run a matching tunnel endpoint separately.")
                Text("The FastAPI backend remains a separate HTTP service and is not the tunnel server.")
                Text("This is a whole-device tunnel proof of concept, not a production per-app VPN product.")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .amonCardStyle()
        }
    }

    private var diagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recent Activity")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                if diagnostics.isEmpty {
                    Text("Tunnel startup activity will appear here after you try to connect.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(diagnostics.suffix(12).enumerated()), id: \.offset) { _, entry in
                        Text(entry)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                }
            }
            .amonCardStyle()
        }
    }

    private func settingsField(title: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            TextField(prompt, text: text)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(AmonTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(AmonTheme.border.opacity(0.85), lineWidth: 1)
                )
        }
    }

    private func numericField(title: String, value: Int, update: @escaping (Int) -> Void, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            TextField(prompt, text: Binding(
                get: { String(value) },
                set: { update(Int($0) ?? value) }
            ))
            .keyboardType(.numberPad)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AmonTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(AmonTheme.border.opacity(0.85), lineWidth: 1)
            )
        }
    }

    private var statusColor: Color {
        switch status.state {
        case .connected:
            return Color(uiColor: .systemGreen)
        case .connecting, .disconnecting:
            return Color(uiColor: .systemOrange)
        case .disconnected:
            return .secondary
        case .failed:
            return Color(uiColor: .systemRed)
        }
    }
}
