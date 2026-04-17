import SwiftUI

public struct ComparePreviewView: View {
    public let artifact: CompareArtifact
    private let itemLookup: [String: Item]

    public init(artifact: CompareArtifact, items: [Item] = []) {
        self.artifact = artifact
        self.itemLookup = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
    }

    private var ownershipSummary: WorkspaceOwnedArtifactSummary {
        artifact.ownedArtifactSummary(items: Array(itemLookup.values))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                ForEach(artifact.rows) { row in
                    VStack(alignment: .leading, spacing: 14) {
                        Text(row.fieldLabel)
                            .font(.headline)

                        VStack(spacing: 10) {
                            ForEach(row.cells) { cell in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(sourceTitle(for: cell.itemID))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)

                                    ForEach(Array(lines(for: cell).enumerated()), id: \.offset) { _, line in
                                        Text(line)
                                            .font(.body)
                                            .foregroundStyle(.primary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }
                        }
                    }
                    .amonCardStyle()
                }
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(artifact.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Structured comparison")
                .font(.title2.weight(.semibold))
            Text(artifact.summary ?? "Amon organized the selected sources into a structured comparison.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                AmonMetadataPill(text: "\(artifact.itemIDs.count) sources")
                AmonMetadataPill(text: "\(artifact.rows.count) fields")
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

    private func sourceTitle(for itemID: String) -> String {
        itemLookup[itemID]?.displayTitle ?? "Saved source"
    }

    private func lines(for cell: CompareCell) -> [String] {
        if let valueText = cell.valueText, !valueText.isEmpty {
            return [valueText]
        }
        if let valueJSON = cell.valueJSON {
            switch valueJSON {
            case .array(let values):
                let items = values.compactMap(\.stringValue)
                return items.isEmpty ? ["No value"] : items
            case .string(let value):
                return [value]
            case .number(let value):
                return [String(value)]
            case .bool(let value):
                return [value ? "Yes" : "No"]
            case .object, .null:
                return ["No value"]
            }
        }
        return ["No value"]
    }
}
