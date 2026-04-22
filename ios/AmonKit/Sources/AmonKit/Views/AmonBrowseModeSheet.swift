import SwiftUI

struct AmonBrowseModeSheet: View {
    @Environment(\.dismiss) private var dismiss

    let choice: BrowseOpenChoicePresentation
    let onSelect: (BrowsePath) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    AmonBrandHeroCard(
                        eyebrow: "Open / Modes",
                        title: "Choose a mode",
                        message: choice.browseSheetMessage,
                        badges: ["Local", "Clean View", "Protected"],
                        compact: true
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(choice.browseSheetTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AmonTheme.ink)
                        Text(choice.browseSheetDomain)
                            .font(.caption)
                            .foregroundStyle(AmonTheme.muted)
                            .textSelection(.enabled)
                    }
                    .padding(.horizontal, 4)

                    VStack(spacing: 10) {
                        modeCard(
                            title: "Local",
                            description: choice.localModeDescription,
                            badgeText: choice.localModeStatusLabel,
                            badgeTone: .neutral,
                            systemImage: "iphone.gen3",
                            actionTitle: choice.localRoutedTitle,
                            isEnabled: true,
                            action: { onSelect(.localRouted) }
                        )

                        modeCard(
                            title: "Clean View",
                            description: choice.cleanModeDescription,
                            badgeText: "Readable fetch",
                            badgeTone: .neutral,
                            systemImage: "doc.text",
                            actionTitle: choice.cleanViewTitle,
                            isEnabled: true,
                            action: { onSelect(.cleanView) }
                        )

                        modeCard(
                            title: "Protected Session",
                            description: choice.protectedModeDescription,
                            badgeText: choice.protectedModeStatusLabel,
                            badgeTone: choice.isProtectedSessionSelectable ? .accent : .warning,
                            systemImage: "lock.shield",
                            actionTitle: choice.protectedSessionTitle,
                            isEnabled: choice.isProtectedSessionSelectable,
                            action: { onSelect(.protectedSession) }
                        )
                    }

                    if choice.showsDirectFallback {
                        VStack(alignment: .leading, spacing: 8) {
                            AmonBrandEyebrow(text: "Fallback")

                            Button {
                                onSelect(.directFallback)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "arrowshape.turn.up.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(AmonTheme.muted)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Open Direct")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(AmonTheme.ink)

                                        Text("Use a direct device open instead of the main Amon modes.")
                                            .font(.footnote)
                                            .foregroundStyle(AmonTheme.muted)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(AmonTheme.muted)
                                }
                                .amonCardStyle(padding: 14)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 20)
            }
            .background(AmonTheme.canvas.ignoresSafeArea())
            .navigationTitle(choice.dialogTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(AmonTheme.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(AmonTheme.softCanvas)
    }

    private func modeCard(
        title: String,
        description: String,
        badgeText: String,
        badgeTone: AmonModeBadge.Tone,
        systemImage: String,
        actionTitle: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isEnabled ? AmonTheme.accent : AmonTheme.muted)
                        .frame(width: 34, height: 34)
                        .background(
                            (isEnabled ? AmonTheme.accent.opacity(0.12) : AmonTheme.pillSurface),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(title)
                                .font(AmonBrandTypography.brandDisplay(size: 22, relativeTo: .title3))
                                .foregroundStyle(AmonTheme.ink)

                            AmonModeBadge(text: badgeText, tone: badgeTone)
                        }

                        Text(description)
                            .font(.footnote)
                            .foregroundStyle(AmonTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack {
                    Text(actionTitle)
                        .font(.footnote.weight(.semibold))
                    Spacer()
                    Image(systemName: isEnabled ? "arrow.up.right" : "minus")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(isEnabled ? AmonTheme.canvas : AmonTheme.muted)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    isEnabled ? AmonTheme.accent : AmonTheme.pillSurface,
                    in: Capsule()
                )
            }
            .amonCardStyle(padding: 15)
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(isEnabled ? AmonTheme.strongBorder : Color.clear, lineWidth: 1)
            )
            .opacity(isEnabled ? 1 : 0.72)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}
