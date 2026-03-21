import SwiftUI

public struct SearchView: View {
    @ObservedObject private var viewModel: SearchViewModel

    public init(viewModel: SearchViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack {
                    TextField("Search / browse", text: $viewModel.query)
                        .textFieldStyle(.roundedBorder)
                    Button("Go") {
                        Task { await viewModel.search() }
                    }
                    .buttonStyle(.borderedProminent)
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                List(viewModel.results, id: \.id, selection: .constant(Set<String>())) { result in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(result.title)
                            .font(.headline)
                        Text(result.domain)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let snippet = result.snippet {
                            Text(snippet)
                                .font(.subheadline)
                        }
                        HStack {
                            Button(viewModel.selectedResultIDs.contains(result.id) ? "Selected" : "Select") {
                                if viewModel.selectedResultIDs.contains(result.id) {
                                    viewModel.selectedResultIDs.remove(result.id)
                                } else {
                                    viewModel.selectedResultIDs.insert(result.id)
                                }
                            }
                            .buttonStyle(.bordered)

                            Button("Save") {
                                viewModel.save(result: result)
                            }
                            .buttonStyle(.borderedProminent)

                            if let url = URL(string: result.url) {
                                NavigationLink("Open") {
                                    WebViewContainer(url: url)
                                        .ignoresSafeArea()
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)

                HStack {
                    Button("Save Selected") {
                        viewModel.saveSelectedResults()
                    }
                    .buttonStyle(.bordered)

                    Button("Compare") {
                        Task { await viewModel.runCompare() }
                    }
                    .buttonStyle(.bordered)

                    Button("Research") {
                        Task { await viewModel.runResearch() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .navigationTitle("Search")
            .sheet(item: Binding(get: {
                viewModel.activeCompare.map(IdentifiedCompare.init)
            }, set: { _ in
                viewModel.activeCompare = nil
            })) { item in
                ComparePreviewView(artifact: item.artifact)
            }
            .sheet(item: Binding(get: {
                viewModel.activeResearch.map(IdentifiedResearch.init)
            }, set: { _ in
                viewModel.activeResearch = nil
            })) { item in
                ResearchPreviewView(artifact: item.artifact)
            }
        }
    }
}

private struct IdentifiedCompare: Identifiable {
    let artifact: CompareArtifact
    var id: String { artifact.id }
}

private struct IdentifiedResearch: Identifiable {
    let artifact: ResearchArtifact
    var id: String { artifact.id }
}
