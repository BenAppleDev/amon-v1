import SwiftUI

struct AmonBrandEyebrow: View {
    let text: String
    var tone: Color = AmonTheme.accent

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(tone)
                .frame(width: 7, height: 7)

            Text(text)
                .font(.caption2.weight(.semibold))
                .tracking(1.6)
                .textCase(.uppercase)
                .foregroundStyle(AmonTheme.muted)
        }
    }
}

struct AmonModeBadge: View {
    enum Tone {
        case accent
        case neutral
        case warning
    }

    let text: String
    var tone: Tone = .neutral

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(backgroundColor, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(borderColor, lineWidth: 1)
            )
    }

    private var foregroundColor: Color {
        switch tone {
        case .accent:
            return AmonTheme.canvas
        case .neutral:
            return AmonTheme.ink
        case .warning:
            return AmonTheme.danger
        }
    }

    private var backgroundColor: Color {
        switch tone {
        case .accent:
            return AmonTheme.accent
        case .neutral:
            return AmonTheme.pillSurface
        case .warning:
            return AmonTheme.danger.opacity(0.12)
        }
    }

    private var borderColor: Color {
        switch tone {
        case .accent:
            return AmonTheme.accent.opacity(0.4)
        case .neutral:
            return AmonTheme.border
        case .warning:
            return AmonTheme.danger.opacity(0.35)
        }
    }
}

struct AmonBrandHeroCard: View {
    let eyebrow: String
    let title: String
    let message: String
    var badges: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            AmonBrandEyebrow(text: eyebrow)

            Text(title)
                .font(AmonBrandTypography.brandDisplay(size: 34, relativeTo: .largeTitle))
                .foregroundStyle(AmonTheme.ink)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(AmonTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            if !badges.isEmpty {
                ViewThatFits {
                    HStack(spacing: 8) {
                        ForEach(badges, id: \.self) { badge in
                            AmonModeBadge(text: badge)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(badges, id: \.self) { badge in
                            AmonModeBadge(text: badge)
                        }
                    }
                }
            }
        }
        .amonCardStyle(padding: 20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            AmonTheme.surface,
                            AmonTheme.elevatedSurface.opacity(0.9),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
}

struct AmonBannerView: View {
    let banner: AmonBanner
    var dismiss: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 28, height: 28)
                .background(iconColor.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(banner.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AmonTheme.ink)
                Text(banner.message)
                    .font(.footnote)
                    .foregroundStyle(AmonTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let dismiss {
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AmonTheme.muted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 1)
        )
    }

    private var iconName: String {
        switch banner.tone {
        case .info:
            return "info.circle.fill"
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }

    private var iconColor: Color {
        switch banner.tone {
        case .info:
            return AmonTheme.accent
        case .success:
            return AmonTheme.accent
        case .error:
            return AmonTheme.danger
        }
    }

    private var backgroundColor: Color {
        switch banner.tone {
        case .info:
            return AmonTheme.elevatedSurface
        case .success:
            return AmonTheme.accent.opacity(0.12)
        case .error:
            return AmonTheme.danger.opacity(0.12)
        }
    }

    private var borderColor: Color {
        switch banner.tone {
        case .info:
            return AmonTheme.border
        case .success:
            return AmonTheme.accent.opacity(0.3)
        case .error:
            return AmonTheme.danger.opacity(0.3)
        }
    }
}

struct AmonTrustStripView: View {
    let items: [String]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                if index > 0 {
                    Circle()
                        .fill(AmonTheme.muted.opacity(0.28))
                        .frame(width: 3, height: 3)
                }
                Text(item)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AmonTheme.muted)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AmonTheme.pillSurface, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(AmonTheme.border, lineWidth: 1)
        )
    }
}

struct AmonEmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(AmonTheme.accent)
                .frame(width: 64, height: 64)
                .background(AmonTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            VStack(spacing: 8) {
                Text(title)
                    .font(AmonBrandTypography.brandDisplay(size: 28, relativeTo: .title3))
                    .foregroundStyle(AmonTheme.ink)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(AmonTheme.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(AmonTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(AmonTheme.border.opacity(0.8), lineWidth: 1)
        )
    }
}

struct AmonMetadataPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(AmonTheme.muted)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AmonTheme.pillSurface, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(AmonTheme.border, lineWidth: 1)
            )
    }
}

struct AmonToolbarIconButton: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(AmonTheme.ink)
            .frame(width: 32, height: 32)
            .background(AmonTheme.elevatedSurface, in: Circle())
            .overlay(
                Circle()
                    .strokeBorder(AmonTheme.border, lineWidth: 1)
            )
    }
}

struct AmonActionChip: View {
    enum Tone {
        case neutral
        case accent
        case selected
    }

    let title: String
    let systemImage: String
    var tone: Tone = .neutral
    var expands = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))

            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.88)
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(foregroundColor)
        .frame(maxWidth: expands ? .infinity : nil, minHeight: 40)
        .padding(.horizontal, 10)
        .background(backgroundColor, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(borderColor, lineWidth: 1)
        )
    }

    private var foregroundColor: Color {
        switch tone {
        case .neutral:
            return AmonTheme.ink
        case .accent, .selected:
            return AmonTheme.canvas
        }
    }

    private var backgroundColor: Color {
        switch tone {
        case .neutral:
            return AmonTheme.pillSurface
        case .accent:
            return AmonTheme.accent
        case .selected:
            return AmonTheme.accent.opacity(0.92)
        }
    }

    private var borderColor: Color {
        switch tone {
        case .neutral:
            return AmonTheme.border.opacity(0.85)
        case .accent, .selected:
            return AmonTheme.accent.opacity(0.28)
        }
    }
}

struct AmonSourcePreviewCard: View {
    let title: String
    let domain: String
    let summary: String?
    let metadata: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AmonTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(domain)
                .font(.caption)
                .foregroundStyle(AmonTheme.muted)

            if !metadata.isEmpty {
                HStack(spacing: 8) {
                    ForEach(metadata, id: \.self) { item in
                        AmonMetadataPill(text: item)
                    }
                }
            }

            if let summary, !summary.isEmpty {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(AmonTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .amonCardStyle(padding: 18)
        .padding(12)
        .frame(maxWidth: 320, alignment: .leading)
        .background(AmonTheme.canvas)
    }
}

extension View {
    func amonCardStyle(padding: CGFloat = 18) -> some View {
        self
            .padding(padding)
            .background(AmonTheme.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(AmonTheme.border, lineWidth: 1)
            )
            .shadow(color: AmonTheme.shadow, radius: 14, y: 7)
    }
}
