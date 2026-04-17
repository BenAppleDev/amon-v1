import Foundation
import XCTest
@testable import AmonKit

@MainActor
final class WorkspaceOwnershipModelsTests: XCTestCase {
    func testCompareArtifactSummaryTracksSourceCoverage() {
        let readableItem = Item(
            id: "item-readable",
            workspaceID: "workspace-1",
            sourceKind: .retrievedPage,
            resultType: .article,
            title: "Readable",
            canonicalURL: "https://example.com/readable",
            domain: "example.com",
            pageTitle: "Readable page",
            cleanedExcerpt: "Readable excerpt",
            fetchedAt: Date()
        )
        let sourceOnlyItem = Item(
            id: "item-source-only",
            workspaceID: "workspace-1",
            sourceKind: .searchResult,
            resultType: .article,
            title: "Source only",
            canonicalURL: "https://example.com/source",
            domain: "example.com"
        )
        let artifact = CompareArtifact(
            id: "compare-1",
            workspaceID: "workspace-1",
            title: "Compare",
            summary: "Structured comparison",
            itemIDs: [readableItem.id, sourceOnlyItem.id]
        )

        let summary = artifact.ownedArtifactSummary(items: [readableItem, sourceOnlyItem])

        XCTAssertEqual(summary.kind, .compare)
        XCTAssertEqual(summary.ownershipTier, .ownedLocalArtifact)
        XCTAssertEqual(summary.sourceCoverage.totalSources, 2)
        XCTAssertEqual(summary.sourceCoverage.ownedReadableSources, 1)
        XCTAssertEqual(summary.sourceCoverage.sourceOnlySources, 1)
        XCTAssertEqual(summary.ownershipBadgeText, "Owned compare")
        XCTAssertEqual(summary.sourceCoverageBadgeText, "1/2 saved copies")
        XCTAssertEqual(
            summary.transitionSummary,
            "1 linked source can still be promoted into readable local copies."
        )
    }

    func testPromoteItemToOwnedReadableCopyStrengthensSavedSource() async throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("amonkit-workspace-promotion-\(UUID().uuidString)", isDirectory: true)
        let databaseURL = directory.appendingPathComponent("workspace.sqlite")

        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let store = try SQLiteWorkspaceStore(
            databaseURL: databaseURL,
            fieldCipher: LocalFieldCipher(fixedKeyData: Data(repeating: 5, count: 32))
        )
        let workspace = try store.createWorkspace(title: "Research Library", description: nil)
        let item = Item(
            workspaceID: workspace.id,
            sourceKind: .searchResult,
            resultType: .article,
            title: "Source only",
            canonicalURL: "https://example.com/source",
            domain: "example.com"
        )
        try store.saveItem(item)

        let apiClient = WorkspaceOwnershipAPIClientStub()
        apiClient.retrievalResponses[item.canonicalURL] = StructuredRetrievalDTO(
            url: item.canonicalURL,
            canonical_url: item.canonicalURL,
            title: "Readable source",
            domain: item.domain,
            excerpt: "Saved readable excerpt",
            bullet_points: ["Point one"],
            retrieved_at: Date()
        )

        let viewModel = WorkspaceDetailViewModel(store: store, workspaceID: workspace.id)

        await viewModel.promoteItemToOwnedReadableCopy(item, apiClient: apiClient)

        let updated = try XCTUnwrap(try store.fetchItems(workspaceID: workspace.id).first)
        XCTAssertTrue(updated.hasOwnedReadableContent)
        XCTAssertEqual(updated.pageTitle, "Readable source")
        XCTAssertEqual(updated.cleanedExcerpt, "Saved readable excerpt")
        XCTAssertEqual(viewModel.banner?.title, "Saved readable copy")
    }

    func testStrengthenLinkedSourcesPromotesArtifactSourceCoverage() async throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("amonkit-artifact-strengthening-\(UUID().uuidString)", isDirectory: true)
        let databaseURL = directory.appendingPathComponent("workspace.sqlite")

        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let store = try SQLiteWorkspaceStore(
            databaseURL: databaseURL,
            fieldCipher: LocalFieldCipher(fixedKeyData: Data(repeating: 6, count: 32))
        )
        let workspace = try store.createWorkspace(title: "Research Library", description: nil)
        let readableItem = Item(
            id: "item-readable",
            workspaceID: workspace.id,
            sourceKind: .retrievedPage,
            resultType: .article,
            title: "Readable",
            canonicalURL: "https://example.com/readable",
            domain: "example.com",
            pageTitle: "Readable page",
            cleanedExcerpt: "Readable excerpt",
            fetchedAt: Date()
        )
        let sourceOnlyItem = Item(
            id: "item-source-only",
            workspaceID: workspace.id,
            sourceKind: .searchResult,
            resultType: .article,
            title: "Source only",
            canonicalURL: "https://example.com/source-only",
            domain: "example.com"
        )
        try store.saveItem(readableItem)
        try store.saveItem(sourceOnlyItem)

        let artifact = CompareArtifact(
            id: "compare-1",
            workspaceID: workspace.id,
            title: "Compare",
            summary: "Structured comparison",
            itemIDs: [readableItem.id, sourceOnlyItem.id]
        )
        try store.saveCompareArtifact(artifact)

        let apiClient = WorkspaceOwnershipAPIClientStub()
        apiClient.retrievalResponses[sourceOnlyItem.canonicalURL] = StructuredRetrievalDTO(
            url: sourceOnlyItem.canonicalURL,
            canonical_url: sourceOnlyItem.canonicalURL,
            title: "Readable source",
            domain: sourceOnlyItem.domain,
            excerpt: "Saved readable excerpt",
            bullet_points: ["Point one"],
            retrieved_at: Date()
        )

        let viewModel = WorkspaceDetailViewModel(store: store, workspaceID: workspace.id)

        await viewModel.strengthenLinkedSources(for: artifact, apiClient: apiClient)

        let refreshedArtifact = try XCTUnwrap(viewModel.compareArtifacts.first)
        let summary = viewModel.ownedArtifactSummary(for: refreshedArtifact)
        XCTAssertEqual(summary.sourceCoverage.totalSources, 2)
        XCTAssertEqual(summary.sourceCoverage.ownedReadableSources, 2)
        XCTAssertEqual(summary.sourceCoverage.sourceOnlySources, 0)
        XCTAssertFalse(summary.sourceCoverage.needsSourcePromotion)
        XCTAssertEqual(viewModel.banner?.title, "Artifact strengthened")

        let updatedItems = try store.fetchItems(workspaceID: workspace.id)
        let strengthenedItem = try XCTUnwrap(updatedItems.first(where: { $0.id == sourceOnlyItem.id }))
        XCTAssertTrue(strengthenedItem.hasOwnedReadableContent)
        XCTAssertEqual(apiClient.retrievalRequests, [sourceOnlyItem.canonicalURL])
    }

    func testStrengthenLinkedSourcesHandlesPartialFailure() async throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("amonkit-artifact-partial-\(UUID().uuidString)", isDirectory: true)
        let databaseURL = directory.appendingPathComponent("workspace.sqlite")

        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let store = try SQLiteWorkspaceStore(
            databaseURL: databaseURL,
            fieldCipher: LocalFieldCipher(fixedKeyData: Data(repeating: 8, count: 32))
        )
        let workspace = try store.createWorkspace(title: "Research Library", description: nil)
        let itemOne = Item(
            id: "item-one",
            workspaceID: workspace.id,
            sourceKind: .searchResult,
            resultType: .article,
            title: "Source one",
            canonicalURL: "https://example.com/one",
            domain: "example.com"
        )
        let itemTwo = Item(
            id: "item-two",
            workspaceID: workspace.id,
            sourceKind: .searchResult,
            resultType: .article,
            title: "Source two",
            canonicalURL: "https://example.com/two",
            domain: "example.com"
        )
        try store.saveItem(itemOne)
        try store.saveItem(itemTwo)

        let artifact = ResearchArtifact(
            id: "research-1",
            workspaceID: workspace.id,
            title: "Research",
            summaryText: "Grounded notes",
            itemIDs: [itemOne.id, itemTwo.id]
        )
        try store.saveResearchArtifact(artifact)

        let apiClient = WorkspaceOwnershipAPIClientStub()
        apiClient.retrievalResponses[itemOne.canonicalURL] = StructuredRetrievalDTO(
            url: itemOne.canonicalURL,
            canonical_url: itemOne.canonicalURL,
            title: "Readable one",
            domain: itemOne.domain,
            excerpt: "Readable one excerpt",
            bullet_points: ["Point one"],
            retrieved_at: Date()
        )
        apiClient.retrievalErrors[itemTwo.canonicalURL] = NSError(domain: "WorkspaceOwnershipAPIClientStub", code: 99)

        let viewModel = WorkspaceDetailViewModel(store: store, workspaceID: workspace.id)

        await viewModel.strengthenLinkedSources(for: artifact, apiClient: apiClient)

        let refreshedArtifact = try XCTUnwrap(viewModel.researchArtifacts.first)
        let summary = viewModel.ownedArtifactSummary(for: refreshedArtifact)
        XCTAssertEqual(summary.sourceCoverage.ownedReadableSources, 1)
        XCTAssertEqual(summary.sourceCoverage.sourceOnlySources, 1)
        XCTAssertTrue(summary.sourceCoverage.needsSourcePromotion)
        XCTAssertEqual(viewModel.banner?.title, "Strengthened some linked sources")

        let updatedItems = try store.fetchItems(workspaceID: workspace.id)
        XCTAssertTrue(try XCTUnwrap(updatedItems.first(where: { $0.id == itemOne.id })).hasOwnedReadableContent)
        XCTAssertFalse(try XCTUnwrap(updatedItems.first(where: { $0.id == itemTwo.id })).hasOwnedReadableContent)
    }
}

private final class WorkspaceOwnershipAPIClientStub: AmonAPIClienting, @unchecked Sendable {
    var retrievalResponses: [String: StructuredRetrievalDTO] = [:]
    var retrievalErrors: [String: Error] = [:]
    var retrievalRequests: [String] = []

    func devLogin(appleSubject: String) async throws -> AuthResponseDTO { throw stubError }
    func me() async throws -> UserDTO { throw stubError }
    func search(query: String, count: Int) async throws -> [SearchResult] { throw stubError }

    func retrieve(url: String) async throws -> StructuredRetrievalDTO {
        retrievalRequests.append(url)
        if let error = retrievalErrors[url] {
            throw error
        }
        if let response = retrievalResponses[url] {
            return response
        }
        throw stubError
    }

    func serveDecision(url: String, intent: ServeDecisionIntentDTO) async throws -> ServeDecisionResponseDTO { throw stubError }
    func createProtectedSession(url: String) async throws -> ProtectedSessionStateDTO { throw stubError }
    func makeProtectedSessionStreamRequest(sessionID: String) throws -> URLRequest { throw stubError }
    func getProtectedSessionState(sessionID: String) async throws -> ProtectedSessionStateDTO { throw stubError }
    func sendProtectedSessionAction(sessionID: String, action: ProtectedSessionActionRequestDTO) async throws -> ProtectedSessionStateDTO { throw stubError }
    func endProtectedSession(sessionID: String) async throws -> ProtectedSessionEndResponseDTO { throw stubError }
    func compare(title: String, items: [Item]) async throws -> CompareResponseDTO { throw stubError }
    func research(title: String, promptContext: String?, items: [Item]) async throws -> ResearchResponseDTO { throw stubError }
    func clearSession() throws {}

    private var stubError: Error {
        NSError(domain: "WorkspaceOwnershipAPIClientStub", code: -1)
    }
}
