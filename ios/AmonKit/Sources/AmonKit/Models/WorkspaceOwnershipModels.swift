import Foundation

// Workspace ownership is incremental in this build:
// - `savedSourceRecord` means Amon owns a local record for the source plus any lightweight metadata.
// - `ownedReadableCopy` means Amon also owns a saved readable snapshot on this device.
// - `ownedLocalArtifact` means Amon owns a deeper local artifact assembled from saved sources on this device.
// Structural linkage, timestamps, and workflow metadata still remain outside a fully opaque database model.
public enum WorkspaceOwnershipTier: String, Codable, Sendable {
    case savedSourceRecord = "saved_source_record"
    case ownedReadableCopy = "owned_readable_copy"
    case ownedLocalArtifact = "owned_local_artifact"
}

public enum WorkspaceItemOwnershipState: String, Codable, Sendable {
    case savedSourceRecord = "saved_source_record"
    case ownedReadableCopy = "owned_readable_copy"
}

public enum WorkspaceOwnedArtifactKind: String, Codable, Sendable {
    case compare
    case research
}

public enum WorkspaceOwnershipLocalityState: String, Codable, Sendable {
    case fullyLocal = "fully_local"
    case partiallyLocal = "partially_local"
    case referenceDependent = "reference_dependent"
}

public struct WorkspaceArtifactSourceCoverage: Equatable, Sendable {
    public let totalSources: Int
    public let ownedReadableSources: Int
    public let sourceOnlySources: Int

    public init(totalSources: Int, ownedReadableSources: Int, sourceOnlySources: Int) {
        self.totalSources = totalSources
        self.ownedReadableSources = ownedReadableSources
        self.sourceOnlySources = sourceOnlySources
    }

    public var allLinkedSourcesHaveReadableCopies: Bool {
        totalSources > 0 && sourceOnlySources == 0
    }

    public var needsSourcePromotion: Bool {
        sourceOnlySources > 0
    }
}

public struct WorkspaceOwnershipSummary: Equatable, Sendable {
    public let totalItems: Int
    public let ownedReadableItems: Int
    public let sourceOnlyItems: Int
    public let ownedLocalArtifacts: Int
    public let artifactsNeedingSourcePromotion: Int
    public let linkedSourceOnlyItems: Int

    public init(
        totalItems: Int,
        ownedReadableItems: Int,
        sourceOnlyItems: Int,
        ownedLocalArtifacts: Int,
        artifactsNeedingSourcePromotion: Int,
        linkedSourceOnlyItems: Int
    ) {
        self.totalItems = totalItems
        self.ownedReadableItems = ownedReadableItems
        self.sourceOnlyItems = sourceOnlyItems
        self.ownedLocalArtifacts = ownedLocalArtifacts
        self.artifactsNeedingSourcePromotion = artifactsNeedingSourcePromotion
        self.linkedSourceOnlyItems = linkedSourceOnlyItems
    }

    public var standaloneSourceOnlyItems: Int {
        max(sourceOnlyItems - linkedSourceOnlyItems, 0)
    }

    public var canStrengthenFurther: Bool {
        sourceOnlyItems > 0
    }

    public var localityState: WorkspaceOwnershipLocalityState {
        if !canStrengthenFurther {
            return .fullyLocal
        }

        if ownedReadableItems > 0 || ownedLocalArtifacts > 0 {
            return .partiallyLocal
        }

        return .referenceDependent
    }
}

public struct WorkspaceOwnedArtifactSummary: Identifiable, Equatable, Sendable {
    public let id: String
    public let kind: WorkspaceOwnedArtifactKind
    public let title: String
    public let bodyPreview: String?
    public let updatedAt: Date
    public let sourceCoverage: WorkspaceArtifactSourceCoverage

    public init(
        id: String,
        kind: WorkspaceOwnedArtifactKind,
        title: String,
        bodyPreview: String?,
        updatedAt: Date,
        sourceCoverage: WorkspaceArtifactSourceCoverage
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.bodyPreview = bodyPreview
        self.updatedAt = updatedAt
        self.sourceCoverage = sourceCoverage
    }

    public var ownershipTier: WorkspaceOwnershipTier {
        .ownedLocalArtifact
    }
}

public extension Item {
    var hasOwnedReadableContent: Bool {
        let hasPageTitle = !(pageTitle?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let hasExcerpt = !(cleanedExcerpt?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        return hasPageTitle || hasExcerpt || !bulletPoints.isEmpty || fetchedAt != nil || sourceKind == .retrievedPage
    }

    var ownershipState: WorkspaceItemOwnershipState {
        hasOwnedReadableContent ? .ownedReadableCopy : .savedSourceRecord
    }

    var ownershipTier: WorkspaceOwnershipTier {
        hasOwnedReadableContent ? .ownedReadableCopy : .savedSourceRecord
    }

    var dependsOnLiveSourceForReadableContent: Bool {
        !hasOwnedReadableContent
    }

    var canPromoteToOwnedReadableCopy: Bool {
        dependsOnLiveSourceForReadableContent
    }
}

public extension CompareArtifact {
    func ownedArtifactSummary(items: [Item]) -> WorkspaceOwnedArtifactSummary {
        WorkspaceOwnedArtifactSummary(
            id: id,
            kind: .compare,
            title: title,
            bodyPreview: summary,
            updatedAt: updatedAt,
            sourceCoverage: workspaceSourceCoverage(items: items)
        )
    }
}

public extension ResearchArtifact {
    func ownedArtifactSummary(items: [Item]) -> WorkspaceOwnedArtifactSummary {
        WorkspaceOwnedArtifactSummary(
            id: id,
            kind: .research,
            title: title,
            bodyPreview: summaryText,
            updatedAt: updatedAt,
            sourceCoverage: workspaceSourceCoverage(items: items)
        )
    }
}

private protocol WorkspaceArtifactSourceReferencing {
    var itemIDs: [String] { get }
}

extension CompareArtifact: WorkspaceArtifactSourceReferencing {}
extension ResearchArtifact: WorkspaceArtifactSourceReferencing {}

private extension WorkspaceArtifactSourceReferencing {
    func workspaceSourceCoverage(items: [Item]) -> WorkspaceArtifactSourceCoverage {
        let itemsByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        let totalSources = itemIDs.count
        let ownedReadableSources = itemIDs.reduce(into: 0) { count, itemID in
            if itemsByID[itemID]?.hasOwnedReadableContent == true {
                count += 1
            }
        }

        return WorkspaceArtifactSourceCoverage(
            totalSources: totalSources,
            ownedReadableSources: ownedReadableSources,
            sourceOnlySources: max(totalSources - ownedReadableSources, 0)
        )
    }
}
