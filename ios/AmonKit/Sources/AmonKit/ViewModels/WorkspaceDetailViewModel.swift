import Foundation

@MainActor
final class WorkspaceDetailViewModel: ObservableObject {
    @Published private(set) var workspace: Workspace?
    @Published private(set) var items: [Item] = []
    @Published private(set) var compareArtifacts: [CompareArtifact] = []
    @Published private(set) var researchArtifacts: [ResearchArtifact] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var promotingItemIDs: Set<String> = []
    @Published private(set) var strengtheningArtifactIDs: Set<String> = []
    @Published private(set) var isStrengtheningWorkspace: Bool = false
    @Published var banner: AmonBanner?

    private let store: WorkspaceStore
    private let workspaceID: String

    init(store: WorkspaceStore, workspaceID: String) {
        self.store = store
        self.workspaceID = workspaceID
        refresh()
    }

    func refresh() {
        isLoading = true
        defer { isLoading = false }

        do {
            workspace = try store.fetchWorkspace(id: workspaceID)
            items = try store.fetchItems(workspaceID: workspaceID)
                .filter { !$0.isDeleted }
                .sorted(by: { $0.updatedAt > $1.updatedAt })
            compareArtifacts = try store.fetchCompareArtifacts(workspaceID: workspaceID)
                .sorted(by: { $0.updatedAt > $1.updatedAt })
            researchArtifacts = try store.fetchResearchArtifacts(workspaceID: workspaceID)
                .sorted(by: { $0.updatedAt > $1.updatedAt })
        } catch {
            banner = AmonBanner(
                tone: .error,
                title: "Couldn't load this workspace",
                message: AmonErrorPresenter.message(for: error, fallback: "Amon couldn't load that workspace.")
            )
        }
    }

    func dismissBanner() {
        banner = nil
    }

    var ownedReadableItemCount: Int {
        items.filter(\.hasOwnedReadableContent).count
    }

    var sourceOnlyItemCount: Int {
        items.count - ownedReadableItemCount
    }

    var ownedLocalArtifactCount: Int {
        compareArtifacts.count + researchArtifacts.count
    }

    var artifactsNeedingSourcePromotionCount: Int {
        compareArtifacts.filter { ownedArtifactSummary(for: $0).sourceCoverage.needsSourcePromotion }.count
            + researchArtifacts.filter { ownedArtifactSummary(for: $0).sourceCoverage.needsSourcePromotion }.count
    }

    var ownershipSummary: WorkspaceOwnershipSummary {
        WorkspaceOwnershipSummary(
            totalItems: items.count,
            ownedReadableItems: ownedReadableItemCount,
            sourceOnlyItems: sourceOnlyItemCount,
            ownedLocalArtifacts: ownedLocalArtifactCount,
            artifactsNeedingSourcePromotion: artifactsNeedingSourcePromotionCount,
            linkedSourceOnlyItems: strengthenableLinkedSourceItemIDs.count
        )
    }

    var ownershipStripItems: [String] {
        ownershipSummary.trustStripItems
    }

    func isPromotingItem(_ itemID: String) -> Bool {
        promotingItemIDs.contains(itemID)
    }

    func isStrengtheningArtifact(_ artifactID: String) -> Bool {
        strengtheningArtifactIDs.contains(artifactID)
    }

    func ownedArtifactSummary(for artifact: CompareArtifact) -> WorkspaceOwnedArtifactSummary {
        artifact.ownedArtifactSummary(items: items)
    }

    func ownedArtifactSummary(for artifact: ResearchArtifact) -> WorkspaceOwnedArtifactSummary {
        artifact.ownedArtifactSummary(items: items)
    }

    func promoteItemToOwnedReadableCopy(_ item: Item, apiClient: any AmonAPIClienting) async {
        guard !isStrengtheningWorkspace else { return }
        guard item.canPromoteToOwnedReadableCopy else { return }
        let result = await promoteItemsToOwnedReadableCopies([item], apiClient: apiClient)

        if result.succeededCount > 0 {
            banner = AmonBanner(
                tone: .success,
                title: "Saved readable copy",
                message: "This source now has a stronger local copy saved in your workspace."
            )
        } else {
            banner = AmonBanner(
                tone: .error,
                title: "Couldn't save readable copy",
                message: result.lastFailureMessage ?? "Amon couldn't strengthen that saved source right now."
            )
        }
    }

    func strengthenLinkedSources(for artifact: CompareArtifact, apiClient: any AmonAPIClienting) async {
        guard !isStrengtheningWorkspace else { return }
        await strengthenLinkedSources(
            artifactID: artifact.id,
            artifactTitle: artifact.title,
            itemIDs: artifact.itemIDs,
            apiClient: apiClient
        )
    }

    func strengthenLinkedSources(for artifact: ResearchArtifact, apiClient: any AmonAPIClienting) async {
        guard !isStrengtheningWorkspace else { return }
        await strengthenLinkedSources(
            artifactID: artifact.id,
            artifactTitle: artifact.title,
            itemIDs: artifact.itemIDs,
            apiClient: apiClient
        )
    }

    private func strengthenLinkedSources(
        artifactID: String,
        artifactTitle: String,
        itemIDs: [String],
        apiClient: any AmonAPIClienting
    ) async {
        guard !strengtheningArtifactIDs.contains(artifactID) else { return }

        let linkedItems = linkedItems(for: itemIDs)
        let promotableItems = linkedItems.filter(\.canPromoteToOwnedReadableCopy)
        let alreadyReadableCount = linkedItems.count - promotableItems.count

        guard !promotableItems.isEmpty else {
            banner = AmonBanner(
                tone: .info,
                title: "Already fully local",
                message: alreadyReadableCount > 0
                    ? "\"\(artifactTitle)\" already links only to saved readable copies."
                    : "That artifact doesn't have linked sources to strengthen in this build."
            )
            return
        }

        strengtheningArtifactIDs.insert(artifactID)
        defer { strengtheningArtifactIDs.remove(artifactID) }

        let result = await promoteItemsToOwnedReadableCopies(promotableItems, apiClient: apiClient)

        if result.failedCount == 0 {
            banner = AmonBanner(
                tone: .success,
                title: "Artifact strengthened",
                message: "Saved readable cop\(result.succeededCount == 1 ? "y" : "ies") for \(result.succeededCount) linked source\(result.succeededCount == 1 ? "" : "s") in \"\(artifactTitle)\"."
            )
            return
        }

        if result.succeededCount > 0 {
            banner = AmonBanner(
                tone: .info,
                title: "Strengthened some linked sources",
                message: "Saved \(result.succeededCount) readable cop\(result.succeededCount == 1 ? "y" : "ies"), but \(result.failedCount) linked source\(result.failedCount == 1 ? "" : "s") still need strengthening."
            )
            return
        }

        banner = AmonBanner(
            tone: .error,
            title: "Couldn't strengthen linked sources",
            message: result.lastFailureMessage ?? "Amon couldn't strengthen those linked sources right now."
        )
    }

    func strengthenWorkspace(apiClient: any AmonAPIClienting) async {
        guard !isStrengtheningWorkspace else { return }

        let summary = ownershipSummary
        let linkedSourceItemIDs = strengthenableLinkedSourceItemIDs
        guard summary.canStrengthenFurther else {
            banner = AmonBanner(
                tone: .info,
                title: "Already fully local",
                message: "This workspace already has readable local copies behind every saved source."
            )
            return
        }

        isStrengtheningWorkspace = true
        defer { isStrengtheningWorkspace = false }

        let result = await promoteItemsToOwnedReadableCopies(strengthenableItems, apiClient: apiClient)

        if result.failedCount == 0 {
            banner = AmonBanner(
                tone: .success,
                title: "Workspace strengthened",
                message: workspaceStrengtheningMessage(
                    result: result,
                    failedCount: result.failedCount,
                    linkedSourceItemIDs: linkedSourceItemIDs
                )
            )
            return
        }

        if result.succeededCount > 0 {
            banner = AmonBanner(
                tone: .info,
                title: "Strengthened some of this workspace",
                message: workspaceStrengtheningMessage(
                    result: result,
                    failedCount: result.failedCount,
                    linkedSourceItemIDs: linkedSourceItemIDs
                )
            )
            return
        }

        banner = AmonBanner(
            tone: .error,
            title: "Couldn't strengthen this workspace",
            message: result.lastFailureMessage ?? "Amon couldn't strengthen the saved references in this workspace right now."
        )
    }

    private func touchWorkspace(id: String) throws {
        guard var workspace = try store.fetchWorkspace(id: id) else { return }
        workspace.updatedAt = Date()
        try store.saveWorkspace(workspace)
    }

    private func linkedItems(for itemIDs: [String]) -> [Item] {
        let itemsByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        return itemIDs.compactMap { itemsByID[$0] }
    }

    private var strengthenableItems: [Item] {
        items.filter(\.canPromoteToOwnedReadableCopy)
    }

    private var strengthenableLinkedSourceItemIDs: Set<String> {
        let linkedIDs = Set(compareArtifacts.flatMap(\.itemIDs) + researchArtifacts.flatMap(\.itemIDs))
        let itemsByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })

        return Set(
            linkedIDs.compactMap { itemID in
                guard let item = itemsByID[itemID], item.canPromoteToOwnedReadableCopy else { return nil }
                return itemID
            }
        )
    }

    private func workspaceStrengtheningMessage(
        result: WorkspaceStrengtheningResult,
        failedCount: Int,
        linkedSourceItemIDs: Set<String>
    ) -> String {
        let succeededCount = result.succeededCount
        let linkedSucceededCount = result.succeededItemIDs.intersection(linkedSourceItemIDs).count

        if failedCount == 0 {
            if linkedSucceededCount > 0 {
                return "Saved readable cop\(succeededCount == 1 ? "y" : "ies") for \(succeededCount) source\(succeededCount == 1 ? "" : "s"), including \(linkedSucceededCount) linked from owned artifacts."
            }
            return "Saved readable cop\(succeededCount == 1 ? "y" : "ies") for \(succeededCount) source\(succeededCount == 1 ? "" : "s") across this workspace."
        }

        if linkedSucceededCount > 0 {
            return "Saved \(succeededCount) readable cop\(succeededCount == 1 ? "y" : "ies"), including \(linkedSucceededCount) linked from owned artifacts, but \(failedCount) source\(failedCount == 1 ? "" : "s") still need strengthening."
        }

        return "Saved \(succeededCount) readable cop\(succeededCount == 1 ? "y" : "ies"), but \(failedCount) source\(failedCount == 1 ? "" : "s") still need strengthening."
    }

    private func promoteItemsToOwnedReadableCopies(
        _ items: [Item],
        apiClient: any AmonAPIClienting
    ) async -> WorkspaceStrengtheningResult {
        guard !items.isEmpty else {
            return WorkspaceStrengtheningResult(
                requestedCount: 0,
                succeededCount: 0,
                failedCount: 0,
                succeededItemIDs: [],
                lastFailureMessage: nil
            )
        }

        var succeededCount = 0
        var failedCount = 0
        var succeededItemIDs = Set<String>()
        var lastFailureMessage: String?
        var touchedWorkspaceIDs = Set<String>()

        for item in items {
            promotingItemIDs.insert(item.id)

            do {
                let retrieved = try await apiClient.retrieve(url: item.canonicalURL)
                let updated = retrieved.merged(into: item)
                try store.saveItem(updated)
                touchedWorkspaceIDs.insert(item.workspaceID)
                succeededCount += 1
                succeededItemIDs.insert(item.id)
            } catch {
                failedCount += 1
                lastFailureMessage = AmonErrorPresenter.message(
                    for: error,
                    fallback: "Amon couldn't strengthen one of the linked sources right now."
                )
            }
            promotingItemIDs.remove(item.id)
        }

        if !touchedWorkspaceIDs.isEmpty {
            for workspaceID in touchedWorkspaceIDs {
                try? touchWorkspace(id: workspaceID)
            }
            refresh()
        }

        return WorkspaceStrengtheningResult(
            requestedCount: items.count,
            succeededCount: succeededCount,
            failedCount: failedCount,
            succeededItemIDs: succeededItemIDs,
            lastFailureMessage: lastFailureMessage
        )
    }
}

private struct WorkspaceStrengtheningResult {
    let requestedCount: Int
    let succeededCount: Int
    let failedCount: Int
    let succeededItemIDs: Set<String>
    let lastFailureMessage: String?
}
