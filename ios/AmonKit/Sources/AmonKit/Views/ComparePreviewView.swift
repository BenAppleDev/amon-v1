import SwiftUI

public struct ComparePreviewView: View {
    public let artifact: CompareArtifact

    public init(artifact: CompareArtifact) {
        self.artifact = artifact
    }

    public var body: some View {
        NavigationStack {
            List {
                if let summary = artifact.summary {
                    Section("Summary") {
                        Text(summary)
                    }
                }
                ForEach(artifact.rows) { row in
                    Section(row.fieldLabel) {
                        ForEach(row.cells) { cell in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(cell.itemID).font(.caption).foregroundStyle(.secondary)
                                if let valueText = cell.valueText {
                                    Text(valueText)
                                } else if case .array(let values) = cell.valueJSON {
                                    ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                                        Text("• \(value.stringValue ?? "")")
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(artifact.title)
        }
    }
}
