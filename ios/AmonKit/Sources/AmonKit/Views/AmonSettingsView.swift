import SwiftUI

public struct AmonSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var searchViewModel: SearchViewModel
    @ObservedObject private var privacySettingsStore: PrivacySettingsStore
    @ObservedObject private var transportSettingsStore: TransportPrivacySettingsStore
    private let localRouteCapability: LocalRouteCapabilitySnapshot
    private let tunnelStatus: TransportTunnelStatusSnapshot
    private let tunnelDiagnostics: [String]
    private let connectTunnel: () -> Void
    private let disconnectTunnel: () -> Void
    @State private var isPresentingDeleteConfirmation = false
    @State private var isDeletingAccount = false

    public init(
        searchViewModel: SearchViewModel,
        privacySettingsStore: PrivacySettingsStore,
        transportSettingsStore: TransportPrivacySettingsStore,
        localRouteCapability: LocalRouteCapabilitySnapshot,
        tunnelStatus: TransportTunnelStatusSnapshot,
        tunnelDiagnostics: [String],
        connectTunnel: @escaping () -> Void,
        disconnectTunnel: @escaping () -> Void
    ) {
        self.searchViewModel = searchViewModel
        self.privacySettingsStore = privacySettingsStore
        self.transportSettingsStore = transportSettingsStore
        self.localRouteCapability = localRouteCapability
        self.tunnelStatus = tunnelStatus
        self.tunnelDiagnostics = tunnelDiagnostics
        self.connectTunnel = connectTunnel
        self.disconnectTunnel = disconnectTunnel
    }

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        TransportSettingsView(
                            store: transportSettingsStore,
                            capability: localRouteCapability,
                            status: tunnelStatus,
                            diagnostics: tunnelDiagnostics,
                            connectAction: connectTunnel,
                            disconnectAction: disconnectTunnel
                        )
                    } label: {
                        settingsRow(
                            title: "Amon Tunnel",
                            message: tunnelStatusLabel,
                            systemImage: "network"
                        )
                    }

                    NavigationLink {
                        PrivacySettingsView(store: privacySettingsStore)
                    } label: {
                        settingsRow(
                            title: "Privacy Controls",
                            message: privacySettingsStore.selectedPreset?.summary ?? "Custom privacy mix",
                            systemImage: "hand.raised"
                        )
                    }
                }

                Section {
                    Button {
                        dismiss()
                        searchViewModel.logOut()
                    } label: {
                        settingsRow(
                            title: "Log Out",
                            message: "Clear the current session from this device",
                            systemImage: "rectangle.portrait.and.arrow.right"
                        )
                    }
                    .buttonStyle(.plain)

                    Button(role: .destructive) {
                        isPresentingDeleteConfirmation = true
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "trash")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.red)
                                .frame(width: 28, height: 28)
                                .background(Color.red.opacity(0.1), in: Circle())

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Delete Account")
                                    .font(.body.weight(.semibold))
                                Text("Currently removes Amon from this device only")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .disabled(isDeletingAccount)
                } header: {
                    Text("Account")
                } footer: {
                    Text("Server-side account deletion is not available in this build yet.")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AmonTheme.canvas)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Delete account from this device?", isPresented: $isPresentingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task {
                        isDeletingAccount = true
                        dismiss()
                        await searchViewModel.deleteAccountFromThisDevice()
                        isDeletingAccount = false
                    }
                }
            } message: {
                Text("This build cannot delete the backend account yet. It will sign you out, clear local workspaces, remove website data, and reset Amon on this device.")
            }
        }
    }

    private func settingsRow(title: String, message: String, systemImage: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28, height: 28)
                .background(Color.accentColor.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var tunnelStatusLabel: String {
        if let detail = localRouteCapability.detail, !detail.isEmpty {
            return "\(localRouteCapability.state.title) • \(detail)"
        }
        return localRouteCapability.state.title
    }
}
