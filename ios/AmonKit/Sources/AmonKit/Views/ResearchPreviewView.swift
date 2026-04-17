import SwiftUI

public struct ResearchPreviewView: View {
    public let artifact: ResearchArtifact
    private let items: [Item]

    public init(artifact: ResearchArtifact, items: [Item] = []) {
        self.artifact = artifact
        self.items = items
    }

    private var ownershipSummary: WorkspaceOwnedArtifactSummary {
        artifact.ownedArtifactSummary(items: items)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                summaryCard

                if !artifact.bulletSummary.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Grounded notes")
                            .font(.headline)
                        ForEach(Array(artifact.bulletSummary.enumerated()), id: \.offset) { _, bullet in
                            HStack(alignment: .top, spacing: 10) {
                                Circle()
                                    .fill(Color.accentColor)
                                    .frame(width: 7, height: 7)
                                    .padding(.top, 8)
                                Text(bullet)
                                    .font(.body)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                    }
                    .amonCardStyle()
                }

                if !items.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sources")
                            .font(.headline)
                        ForEach(items) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.displayTitle)
                                    .font(.subheadline.weight(.semibold))
                                Text(item.domain)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                    .amonCardStyle()
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Model")
                        .font(.headline)
                    Text("\(artifact.modelName ?? "unknown") · \(artifact.modelVersion ?? "local")")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .amonCardStyle()
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(artifact.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Research summary")
                .font(.title2.weight(.semibold))
            Text(artifact.summaryText)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                AmonMetadataPill(text: "\(artifact.itemIDs.count) sources")
                AmonMetadataPill(text: ownershipSummary.ownershipBadgeText)
            }

            AmonTrustStripView(items: ownershipSummary.trustStripItems)

            if let transitionSummary = ownershipSummary.transitionSummary {
                Text(transitionSummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .amonCardStyle(padding: 20)
    }
}
