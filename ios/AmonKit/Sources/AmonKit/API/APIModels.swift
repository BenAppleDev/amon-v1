import Foundation

public struct AmonBackendErrorContext: Equatable, Sendable {
    public let statusCode: Int
    public let code: String?
    public let message: String?

    public init(statusCode: Int, code: String?, message: String?) {
        self.statusCode = statusCode
        self.code = code
        self.message = message
    }
}

public struct ProviderInfoDTO: Codable, Equatable, Sendable {
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

public struct ProtectedSessionCreateRequestDTO: Codable, Sendable {
    public var url: String
}

public enum ServeDecisionIntentDTO: String, Codable, Sendable {
    case open
    case protectedSession = "protected_session"
}

public struct ServeDecisionRequestDTO: Codable, Sendable {
    public var url: String
    public var intent: ServeDecisionIntentDTO

    public init(url: String, intent: ServeDecisionIntentDTO) {
        self.url = url
        self.intent = intent
    }
}

public enum ServeDecisionDispositionDTO: String, Codable, Sendable {
    case allowLocal = "ALLOW_LOCAL"
    case allowCleanView = "ALLOW_CLEAN_VIEW"
    case recommendProtected = "RECOMMEND_PROTECTED"
    case allowProtected = "ALLOW_PROTECTED"
    case deny = "DENY"
}

public struct ServeDecisionResponseDTO: Codable, Sendable {
    public var disposition: ServeDecisionDispositionDTO
    public var reason_code: String
    public var confidence: Double
    public var policy_version: String
    public var site_class: String?
    public var budget_tier: String?
}

public enum ProtectedSessionActionKindDTO: String, Codable, Sendable {
    case reload
    case back
    case forward
    case clickLink = "click_link"
    case updateField = "update_field"
    case submitForm = "submit_form"
    case navigateToURL = "navigate_to_url"
}

public struct ProtectedSessionActionRequestDTO: Codable, Sendable {
    public var action: ProtectedSessionActionKindDTO
    public var link_id: String?
    public var form_id: String?
    public var field_name: String?
    public var value: String?
    public var url: String?

    public init(
        action: ProtectedSessionActionKindDTO,
        link_id: String? = nil,
        form_id: String? = nil,
        field_name: String? = nil,
        value: String? = nil,
        url: String? = nil
    ) {
        self.action = action
        self.link_id = link_id
        self.form_id = form_id
        self.field_name = field_name
        self.value = value
        self.url = url
    }
}

public struct ProtectedSessionLinkDTO: Codable, Sendable {
    public var id: String
    public var label: String
    public var url: String
}

public struct ProtectedSessionFieldDTO: Codable, Sendable {
    public var name: String
    public var label: String
    public var field_type: String
    public var value: String?
    public var placeholder: String?
}

public struct ProtectedSessionFormDTO: Codable, Sendable {
    public var id: String
    public var action_url: String
    public var method: String
    public var submit_label: String
    public var fields: [ProtectedSessionFieldDTO]
}

public struct ProtectedSessionPageDTO: Codable, Sendable {
    public var url: String
    public var title: String
    public var domain: String
    public var excerpt: String?
    public var text_blocks: [String]
    public var links: [ProtectedSessionLinkDTO]
    public var forms: [ProtectedSessionFormDTO]
    public var fetched_at: Date
}

public struct ProtectedSessionFrameDTO: Codable, Sendable {
    public var revision: Int
    public var mime_type: String
    public var document: String
    public var width: Int
    public var height: Int
    public var generated_at: Date
}

public struct ProtectedSessionStateDTO: Codable, Sendable {
    public var session_id: String
    public var status: String
    public var allowed_host: String
    public var started_at: Date
    public var expires_at: Date
    public var last_activity_at: Date
    public var can_go_back: Bool
    public var can_go_forward: Bool
    public var content_revision: Int
    public var runtime_kind: String
    public var stream_transport: String?
    public var worker_id: String?
    public var worker_type: String?
    public var worker_state: String?
    public var worker_health: String?
    public var current_frame: ProtectedSessionFrameDTO?
    public var current_page: ProtectedSessionPageDTO?
    public var detail_message: String?
}

public struct ProtectedSessionEndResponseDTO: Codable, Sendable {
    public var session_id: String
    public var status: String
}

public struct ProtectedSessionStreamClientMessageDTO: Codable, Sendable {
    public var type: String
    public var client_message_id: String?
    public var client_action_id: String?
    public var last_stream_sequence: Int?
    public var expected_content_revision: Int?
    public var action: ProtectedSessionActionRequestDTO?
}

public struct ProtectedSessionStreamMessageDTO: Codable, Sendable {
    public var type: String
    public var session_id: String
    public var stream_sequence: Int
    public var content_revision: Int?
    public var state: ProtectedSessionStateDTO?
    public var resumed: Bool?
    public var source_action_id: String?
    public var client_action_id: String?
    public var action_status: String?
    public var code: String?
    public var message: String?
    public var worker_state: String?
    public var worker_health: String?
    public var dropped_events: Int?
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
    public var expires_at: String
    public var user: UserDTO
}
