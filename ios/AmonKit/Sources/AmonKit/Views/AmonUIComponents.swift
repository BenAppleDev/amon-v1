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
            return Color(uiColor: .secondarySystemBackground)
        case .success:
            return Color(uiColor: .systemGreen).opacity(0.08)
        case .error:
            return Color(uiColor: .systemOrange).opacity(0.1)
        }
    }

    private var borderColor: Color {
        switch banner.tone {
        case .info:
            return Color(uiColor: .separator).opacity(0.18)
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
        HStack(spacing: 10) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                if index > 0 {
                    Circle()
                        .fill(Color.secondary.opacity(0.35))
                        .frame(width: 4, height: 4)
                }
                Text(item)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground), in: Capsule())
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
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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
            .background(Color(uiColor: .secondarySystemBackground), in: Capsule())
    }
}

extension View {
    func amonCardStyle(padding: CGFloat = 18) -> some View {
        self
            .padding(padding)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color(uiColor: .separator).opacity(0.16), lineWidth: 1)
            )
    }
}
