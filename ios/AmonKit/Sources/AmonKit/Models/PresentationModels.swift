import Foundation

struct AmonBanner: Identifiable, Equatable {
    enum Tone: Equatable {
        case info
        case success
        case error
    }

    let id = UUID()
    let tone: Tone
    let title: String
    let message: String
}

enum SearchPresentation: Identifiable, Equatable {
    case compare(CompareArtifact, [Item])
    case research(ResearchArtifact, [Item])

    var id: String {
        switch self {
        case .compare(let artifact, _):
            return "compare-\(artifact.id)"
        case .research(let artifact, _):
            return "research-\(artifact.id)"
        }
    }
}

enum AmonErrorPresenter {
    private struct ServerErrorBody: Decodable {
        let code: String?
        let detail: ServerErrorDetail?

        var detailMessage: String? {
            detail?.message ?? detail?.stringValue
        }

        var detailCode: String? {
            detail?.code ?? code
        }
    }

    private enum ServerErrorDetail: Decodable {
        case string(String)
        case object(ServerErrorObject)

        var stringValue: String? {
            if case .string(let value) = self {
                return value
            }
            return nil
        }

        var message: String? {
            if case .object(let value) = self {
                return value.message
            }
            return nil
        }

        var code: String? {
            if case .object(let value) = self {
                return value.code
            }
            return nil
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let value = try? container.decode(String.self) {
                self = .string(value)
                return
            }
            self = .object(try container.decode(ServerErrorObject.self))
        }
    }

    private struct ServerErrorObject: Decodable {
        let code: String?
        let message: String?
    }

    static func message(for error: Error, fallback: String) -> String {
        if let apiError = error as? AmonAPIError {
            switch apiError {
            case .invalidURL:
                return "Amon couldn't prepare that request."
            case .unauthorized:
                return "Your session ended. Sign in again to keep going."
            case .decodingError:
                return "Amon received an unreadable response from the backend."
            case .serverError(let statusCode, let body):
                let detail = serverDetail(from: body)
                let code = serverCode(from: body)
                if code == "retrieve_blocked" {
                    return detail ?? "That site blocked Amon's clean-view fetch. You can still open the original page directly."
                }
                if code == "retrieve_timeout" {
                    return detail ?? "Amon couldn't prepare a clean view before the site timed out. You can still open the original page directly."
                }
                if code == "retrieve_not_found" {
                    return detail ?? "Amon couldn't find that page to prepare a clean view."
                }
                if code == "retrieve_unreachable" || code == "retrieve_client_error" || code == "retrieve_upstream_error" {
                    return detail ?? "Amon couldn't prepare a clean view for that page right now."
                }
                if code == "protected_session_host_not_allowed" {
                    return detail ?? "Protected Session is limited to a small allowlist in this build."
                }
                if code == "protected_session_expired" {
                    return detail ?? "That protected session expired and was cleared remotely."
                }
                if code == "protected_session_terminating" {
                    return detail ?? "That protected session is ending and won't accept new actions."
                }
                if code == "protected_session_closed" {
                    return detail ?? "That protected session was closed and its remote state was destroyed."
                }
                if code == "protected_session_failed" {
                    return detail ?? "Amon couldn't keep that protected session running, and its remote state was destroyed."
                }
                if code == "protected_session_missing" {
                    return detail ?? "That protected session is no longer available."
                }
                if code == "protected_session_starting" {
                    return detail ?? "That protected session is still starting."
                }
                if code == "protected_session_navigation_blocked" {
                    return detail ?? "That remote session is limited to its original host in this build."
                }
                if code == "protected_session_blocked_address" {
                    return detail ?? "That destination is blocked in Protected Session."
                }
                if code == "protected_session_invalid_url" || code == "protected_session_invalid_port" {
                    return detail ?? "That destination isn't allowed in Protected Session."
                }
                if code == "protected_session_non_html" {
                    return detail ?? "That response was not an HTML page the protected session could render."
                }
                if code == "protected_session_response_too_large" {
                    return detail ?? "That page was too large for this Protected Session build."
                }
                if code == "protected_session_parse_failed" {
                    return detail ?? "Amon couldn't interpret that remote page."
                }
                if code == "protected_session_resolution_failed"
                    || code == "protected_session_timeout"
                    || code == "protected_session_unreachable"
                    || code == "protected_session_upstream_error"
                    || code == "protected_session_unavailable" {
                    return detail ?? "Amon couldn't keep that protected session running right now."
                }
                if statusCode == 503 {
                    return detail ?? "Amon can't reach that service right now. Check that the backend is running."
                }
                if statusCode == 403 {
                    return detail ?? "That request was blocked."
                }
                if statusCode >= 500 {
                    return detail ?? "The backend couldn't complete that request right now."
                }
                return detail ?? "That request couldn't be completed."
            }
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .cannotConnectToHost, .cannotFindHost, .timedOut, .networkConnectionLost:
                return "Amon can't reach the backend right now. Make sure your local server is running and reachable from the device."
            default:
                return "The network request failed before Amon could finish it."
            }
        }

        return fallback
    }

    static func isUnauthorized(_ error: Error) -> Bool {
        if let apiError = error as? AmonAPIError {
            switch apiError {
            case .unauthorized:
                return true
            case .serverError(_, let body):
                let detail = serverDetail(from: body)?.lowercased() ?? ""
                return detail.contains("expired session")
                    || detail.contains("invalid session")
                    || detail.contains("missing bearer token")
            default:
                return false
            }
        }
        return false
    }

    private static func serverDetail(from body: String) -> String? {
        guard !body.isEmpty, let data = body.data(using: .utf8) else { return nil }
        if let envelope = try? JSONDecoder().decode(ServerErrorBody.self, from: data) {
            return envelope.detailMessage
        }
        return body.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    private static func serverCode(from body: String) -> String? {
        guard !body.isEmpty, let data = body.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ServerErrorBody.self, from: data).detailCode
    }
}

enum AmonFormatters {
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    static func relativeTimestamp(for date: Date) -> String {
        relativeFormatter.localizedString(for: date, relativeTo: Date())
    }
}

extension SearchResult {
    var metadataPills: [String] {
        var values: [String] = []
        if let age = typed_metadata?["age"]?.stringValue, !age.isEmpty {
            values.append(age)
        }
        switch result_type {
        case .article:
            values.append("Article")
        case .place:
            values.append("Place")
        case .product:
            values.append("Product")
        case .webPage:
            break
        }
        return Array(values.prefix(2))
    }
}

extension Item {
    var displayTitle: String {
        pageTitle ?? title
    }

    var previewText: String? {
        cleanedExcerpt ?? snippet
    }

    var ownershipBadgeText: String {
        switch ownershipState {
        case .savedSourceRecord:
            return "Saved reference"
        case .ownedReadableCopy:
            return "Owned copy"
        }
    }

    var ownershipSummary: String {
        switch ownershipState {
        case .savedSourceRecord:
            return "Only a saved source reference is stored locally for this item."
        case .ownedReadableCopy:
            return "A readable local copy is saved on this device."
        }
    }

    var ownershipTransitionText: String? {
        switch ownershipState {
        case .savedSourceRecord:
            return "Save a readable copy to make this source a stronger local artifact."
        case .ownedReadableCopy:
            return nil
        }
    }

    var localReaderSnapshot: StructuredRetrievalDTO? {
        guard hasOwnedReadableContent else { return nil }
        return StructuredRetrievalDTO(
            url: canonicalURL,
            canonical_url: canonicalURL,
            title: displayTitle,
            domain: domain,
            excerpt: cleanedExcerpt,
            bullet_points: bulletPoints,
            retrieved_at: fetchedAt ?? updatedAt
        )
    }
}

extension WorkspaceOwnedArtifactSummary {
    var ownershipBadgeText: String {
        switch kind {
        case .compare:
            return "Owned compare"
        case .research:
            return "Owned research"
        }
    }

    var ownershipSummary: String {
        switch kind {
        case .compare:
            return "This comparison is saved locally as an owned artifact."
        case .research:
            return "This research output is saved locally as an owned artifact."
        }
    }

    var sourceCoverageBadgeText: String {
        if sourceCoverage.totalSources == 0 {
            return "No linked sources"
        }
        if sourceCoverage.sourceOnlySources == 0 {
            return "\(sourceCoverage.totalSources) saved cop\(sourceCoverage.totalSources == 1 ? "y" : "ies")"
        }
        if sourceCoverage.ownedReadableSources == 0 {
            return "\(sourceCoverage.sourceOnlySources) source-only"
        }
        return "\(sourceCoverage.ownedReadableSources)/\(sourceCoverage.totalSources) saved copies"
    }

    var transitionSummary: String? {
        guard sourceCoverage.needsSourcePromotion else { return nil }
        let count = sourceCoverage.sourceOnlySources
        return "\(count) linked source\(count == 1 ? "" : "s") can still be promoted into readable local copies."
    }

    var trustStripItems: [String] {
        var items = ["Owned locally", "\(sourceCoverage.totalSources) source\(sourceCoverage.totalSources == 1 ? "" : "s")"]
        if sourceCoverage.sourceOnlySources > 0 {
            items.append("\(sourceCoverage.sourceOnlySources) source-only")
        } else if sourceCoverage.totalSources > 0 {
            items.append("All readable locally")
        } else {
            items.append("No backend fetch")
        }
        return items
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
