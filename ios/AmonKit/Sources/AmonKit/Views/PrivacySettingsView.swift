import SwiftUI

public struct PrivacySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store: PrivacySettingsStore
    @State private var banner: AmonBanner?
    @State private var isClearingBrowsingData = false

    public init(store: PrivacySettingsStore) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AmonTheme.canvas
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        presetSection

                        if let banner {
                            AmonBannerView(banner: banner) {
                                self.banner = nil
                            }
                        }

                        browsingSection
                        retrievalSection
                        workspaceSection
                        limitsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Privacy")
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
            if let preset = store.selectedPreset {
                AmonTrustStripView(items: [preset.title, preset.summary])
            } else {
                AmonTrustStripView(items: ["Custom settings", "Preset no longer matches exactly"])
            }

            Text("Choose a preset first, then adjust the details only if you need to.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var presetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Privacy Mode")
                .font(.headline)

            ForEach(PrivacyPreset.allCases) { preset in
                Button {
                    store.applyPreset(preset)
                } label: {
                    PrivacyPresetCard(
                        preset: preset,
                        isSelected: store.selectedPreset == preset
                    )
                }
                .buttonStyle(.plain)
            }

            if store.selectedPreset == .strict {
                Text("Strict mode favors clean reader views and isolated site sessions. Some sites may work better if you switch browsing back to Standard.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
    }

    private var browsingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Browsing Privacy")
                .font(.headline)

            VStack(alignment: .leading, spacing: 16) {
                settingHeader(
                    title: "Default browsing mode",
                    message: "Standard opens a site directly. Clean View asks Amon to fetch a readable version first."
                )

                Picker(
                    "Default browsing mode",
                    selection: Binding(
                        get: { store.settings.browsing.defaultBrowsingMode },
                        set: { store.updateBrowsingMode($0) }
                    )
                ) {
                    ForEach(DefaultBrowsingMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                settingHeader(
                    title: "Website session state",
                    message: "This controls how much site data Amon retains on this device when pages open in Standard mode."
                )

                Picker(
                    "Website session state",
                    selection: Binding(
                        get: { store.settings.browsing.sessionPersistence },
                        set: { store.updateSessionPersistence($0) }
                    )
                ) {
                    ForEach(BrowsingSessionPersistence.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(store.settings.browsing.sessionPersistence.summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button {
                    Task {
                        isClearingBrowsingData = true
                        await BrowserPrivacyController.clearWebsiteData()
                        isClearingBrowsingData = false
                        banner = AmonBanner(
                            tone: .success,
                            title: "Browsing state cleared",
                            message: "Website cookies, storage, and cached session data were removed from this device."
                        )
                    }
                } label: {
                    HStack {
                        if isClearingBrowsingData {
                            ProgressView()
                                .progressViewStyle(.circular)
                        }
                        Text("Clear browsing state now")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(isClearingBrowsingData)
            }
            .amonCardStyle()
        }
    }

    private var retrievalSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Retrieval Privacy")
                .font(.headline)

            VStack(alignment: .leading, spacing: 14) {
                settingToggle(
                    title: "Use reader retrieval for Compare and Research",
                    message: "Amon fetches readable content on your behalf before deeper modes run.",
                    isOn: Binding(
                        get: { store.settings.retrieval.useBackendReaderForDeeperModes },
                        set: { store.updateUseBackendReaderForDeeperModes($0) }
                    )
                )

                Divider()

                settingToggle(
                    title: "Save readable extracts locally",
                    message: "When reader retrieval is used, store the cleaned excerpt and bullet points on this device for future work.",
                    isOn: Binding(
                        get: { store.settings.retrieval.saveRetrievedContentLocally },
                        set: { store.updateSaveRetrievedContentLocally($0) }
                    )
                )
                .disabled(!store.settings.retrieval.useBackendReaderForDeeperModes)
                .opacity(store.settings.retrieval.useBackendReaderForDeeperModes ? 1 : 0.55)

                AmonTrustStripView(items: ["Fresh backend request", "No website cookie reuse on the server today"])
            }
            .amonCardStyle()
        }
    }

    private var workspaceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Workspace Privacy")
                .font(.headline)

            VStack(alignment: .leading, spacing: 14) {
                settingToggle(
                    title: "Save sources automatically for deeper modes",
                    message: "When this is off, Compare and Research only run on sources you have already saved.",
                    isOn: Binding(
                        get: { store.settings.workspace.autoSaveSourcesForDeeperModes },
                        set: { store.updateAutoSaveSourcesForDeeperModes($0) }
                    )
                )

                Text("Saved work remains on this device, and sensitive workspace fields stay protected in the local store.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .amonCardStyle()
        }
    }

    private var limitsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Current Limits")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                Text("Amon does not yet provide a privacy relay or route for normal site browsing.")
                Text("Backend retrieval already uses one-off fetches, but there is no separate user-facing control for backend-side site sessions yet.")
                Text("Workspace locking and export/import confirmation UI are not exposed in this build yet.")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .amonCardStyle()
        }
    }

    private func settingHeader(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func settingToggle(title: String, message: String, isOn: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: isOn) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }

            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct PrivacyPresetCard: View {
    let preset: PrivacyPreset
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(preset.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(preset.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isSelected ? Color.accentColor : Color(uiColor: .tertiaryLabel))
        }
        .padding(18)
        .background(
            isSelected ? Color.accentColor.opacity(0.08) : Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.accentColor.opacity(0.24) : Color(uiColor: .separator).opacity(0.16),
                    lineWidth: 1
                )
        )
    }
}
