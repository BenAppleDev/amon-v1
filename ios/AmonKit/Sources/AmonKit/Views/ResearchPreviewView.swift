import SwiftUI

public struct ResearchPreviewView: View {
    public let artifact: ResearchArtifact

    public init(artifact: ResearchArtifact) {
        self.artifact = artifact
    }

    public var body: some View {
        NavigationStack {
            List {
                Section("Summary") {
                    Text(artifact.summaryText)
                }
                if !artifact.bulletSummary.isEmpty {
                    Section("Bullets") {
                        ForEach(artifact.bulletSummary, id: \.self) { bullet in
                            Text("• \(bullet)")
                        }
                    }
                }
                Section("Model") {
                    Text("\(artifact.modelName ?? "unknown") · \(artifact.modelVersion ?? "")")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(artifact.title)
        }
    }
}
