import Foundation

public protocol WorkspaceStore {
    func createWorkspace(title: String, description: String?) throws -> Workspace
    func saveWorkspace(_ workspace: Workspace) throws
    func fetchWorkspaces() throws -> [Workspace]
    func fetchWorkspace(id: String) throws -> Workspace?

    func saveItem(_ item: Item) throws
    func fetchItems(workspaceID: String) throws -> [Item]

    func saveNote(_ note: Note) throws
    func fetchNotes(workspaceID: String) throws -> [Note]

    func saveCompareArtifact(_ artifact: CompareArtifact) throws
    func fetchCompareArtifacts(workspaceID: String) throws -> [CompareArtifact]

    func saveResearchArtifact(_ artifact: ResearchArtifact) throws
    func fetchResearchArtifacts(workspaceID: String) throws -> [ResearchArtifact]

    func saveExportRecord(_ record: ExportRecord) throws

    func buildWorkspaceGraph(workspaceID: String) throws -> WorkspaceGraph?
    func importWorkspaceGraph(_ graph: WorkspaceGraph) throws
    func resetLocalData() throws
}
