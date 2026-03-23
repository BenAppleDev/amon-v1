import SwiftUI

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
                    .foregroundStyle(.primary)
                Text(banner.message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let dismiss {
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
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
            return Color(uiColor: .systemBlue)
        case .success:
            return Color(uiColor: .systemGreen)
        case .error:
            return Color(uiColor: .systemOrange)
        }
    }

    private var backgroundColor: Color {
        switch banner.tone {
        case .info:
            return AmonTheme.elevatedSurface
        case .success:
            return Color(uiColor: .systemGreen).opacity(0.08)
        case .error:
            return Color(uiColor: .systemOrange).opacity(0.1)
        }
    }

    private var borderColor: Color {
        switch banner.tone {
        case .info:
            return AmonTheme.border.opacity(0.85)
        case .success:
            return Color(uiColor: .systemGreen).opacity(0.18)
        case .error:
            return Color(uiColor: .systemOrange).opacity(0.2)
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
                        .fill(Color.secondary.opacity(0.28))
                        .frame(width: 3, height: 3)
                }
                Text(item)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AmonTheme.pillSurface, in: Capsule())
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
                .foregroundStyle(Color.accentColor)
                .frame(width: 64, height: 64)
                .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            VStack(spacing: 8) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AmonTheme.pillSurface, in: Capsule())
    }
}

struct AmonToolbarIconButton: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(width: 32, height: 32)
            .background(AmonTheme.elevatedSurface, in: Circle())
            .overlay(
                Circle()
                    .strokeBorder(AmonTheme.border.opacity(0.8), lineWidth: 1)
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
        .frame(maxWidth: .infinity, minHeight: 40)
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
            return .primary
        case .accent, .selected:
            return .white
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
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text(domain)
                .font(.caption)
                .foregroundStyle(.secondary)

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
                    .foregroundStyle(.secondary)
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
            .background(AmonTheme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(AmonTheme.border.opacity(0.85), lineWidth: 1)
            )
            .shadow(color: AmonTheme.shadow, radius: 14, y: 7)
    }
}
