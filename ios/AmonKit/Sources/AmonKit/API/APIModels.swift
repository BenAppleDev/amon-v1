import Foundation

public struct ProviderInfoDTO: Codable, Sendable {
    public var name: String
    public var provider_result_id: String?
}

public struct SearchResult: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var url: String
    public var snippet: String?
    public var result_type: ResultType
    public var domain: String
    public var typed_metadata: [String: JSONValue]?
    public var provider: ProviderInfoDTO

    public func toItem(workspaceID: String) -> Item {
        Item(
            workspaceID: workspaceID,
            sourceKind: .searchResult,
            resultType: result_type,
            title: title,
            canonicalURL: url,
            domain: domain,
            snippet: snippet,
            providerName: provider.name,
            providerResultID: provider.provider_result_id,
            typedMetadata: typed_metadata ?? [:]
        )
    }
}

public struct SearchRequestDTO: Codable, Sendable {
    public var query: String
    public var count: Int
}

public struct SearchResponseDTO: Codable, Sendable {
    public var results: [SearchResult]
}

public struct RetrieveRequestDTO: Codable, Sendable {
    public var url: String
}

public struct StructuredRetrievalDTO: Codable, Sendable {
    public var url: String
    public var canonical_url: String
    public var title: String
    public var domain: String
    public var excerpt: String?
    public var bullet_points: [String]
    public var retrieved_at: Date

    public func merged(into item: Item) -> Item {
        var updated = item
        updated.sourceKind = .retrievedPage
        updated.pageTitle = title
        updated.cleanedExcerpt = excerpt
        updated.bulletPoints = bullet_points
        updated.fetchedAt = retrieved_at
        updated.updatedAt = Date()
        return updated
    }
}

public struct ItemSourcePayloadDTO: Codable, Sendable {
    public var item_id: String?
    public var title: String
    public var url: String
    public var domain: String
    public var snippet: String?
    public var page_title: String?
    public var cleaned_excerpt: String?
    public var bullet_points: [String]
    public var typed_metadata: [String: JSONValue]?

    public init(item: Item) {
        self.item_id = item.id
        self.title = item.title
        self.url = item.canonicalURL
        self.domain = item.domain
        self.snippet = item.snippet
        self.page_title = item.pageTitle
        self.cleaned_excerpt = item.cleanedExcerpt
        self.bullet_points = item.bulletPoints
        self.typed_metadata = item.typedMetadata
    }
}

public struct CompareRequestDTO: Codable, Sendable {
    public var title: String
    public var items: [ItemSourcePayloadDTO]
}

public struct CompareCellDTO: Codable, Sendable {
    public var item_id: String?
    public var value_text: String?
    public var value_json: JSONValue?
}

public struct CompareRowDTO: Codable, Sendable {
    public var field_key: String
    public var field_label: String
    public var row_type: CompareRowType
    public var cells: [CompareCellDTO]
}

public struct CompareResponseDTO: Codable, Sendable {
    public var title: String
    public var summary: String
    public var rows: [CompareRowDTO]
}

public struct ResearchRequestDTO: Codable, Sendable {
    public var title: String
    public var prompt_context: String?
    public var items: [ItemSourcePayloadDTO]
}

public struct ResearchSourceDTO: Codable, Sendable {
    public var item_id: String?
}

public struct ModelInfoDTO: Codable, Sendable {
    public var name: String
    public var version: String
}

public struct ResearchResponseDTO: Codable, Sendable {
    public var title: String
    public var summary_text: String
    public var bullet_summary: [String]
    public var sources: [ResearchSourceDTO]
    public var model: ModelInfoDTO
}

public struct DevLoginRequestDTO: Codable, Sendable {
    public var apple_subject: String
}

public struct UserDTO: Codable, Sendable {
    public var id: String
    public var status: String
    public var entitlement_tier: String
    public var entitlement_status: String
}

public struct AuthResponseDTO: Codable, Sendable {
    public var access_token: String
    public var token_type: String
    public var expires_at: Date
    public var user: UserDTO
}
