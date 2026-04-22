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
    static func message(for error: Error, fallback: String) -> String {
        if let apiError = error as? AmonAPIError {
            switch apiError {
            case .invalidURL:
                return "Amon couldn't prepare that request."
            case .unauthorized:
                return "Your session ended. Sign in again to keep going."
            case .decodingError:
                return "Amon received an unreadable response from the backend."
            case .serverError(let context):
                let detail = context.message
                let code = context.code
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
                if code == "missing_bearer_token" {
                    return detail ?? "This device no longer has a signed-in bearer token. Sign in again before starting the routed-local tunnel."
                }
                if code == "product_session_missing" || code == "product_session_revoked" || code == "product_session_expired" {
                    return detail ?? "This device no longer has a valid product session for routed-local startup. Sign in again before connecting."
                }
                if code == "auth_session_invalid" {
                    return detail ?? "The signed-in auth session tied to this device is no longer valid. Sign in again before connecting."
                }
                if code == "entitlement_missing" || code == "account_missing" {
                    return detail ?? "The access context tied to this device is no longer valid for routed-local startup."
                }
                if code == "route_product_session_missing" || code == "route_product_session_invalid" {
                    return detail ?? "The routed-local session's parent product session is no longer valid."
                }
                if context.statusCode == 503 {
                    return detail ?? "Amon can't reach that service right now. Check that the backend is running."
                }
                if context.statusCode == 403 {
                    return detail ?? "That request was blocked."
                }
                if context.statusCode == 401 {
                    return detail ?? "Your signed-in session is no longer valid for that request."
                }
                if context.statusCode >= 500 {
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
            case .serverError(let context):
                if context.statusCode == 401 {
                    return true
                }
                let detail = context.message?.lowercased() ?? ""
                return detail.contains("expired session")
                    || detail.contains("invalid session")
                    || detail.contains("missing bearer token")
            default:
                return false
            }
        }
        return false
    }

    static func protectedSessionTerminalState(
        for error: Error,
        fallback: String
    ) -> ProtectedSessionLifecycleState? {
        let message = message(for: error, fallback: fallback)

        if let apiError = error as? AmonAPIError {
            switch apiError.backendCode {
            case "protected_session_expired":
                return .expired(message: message)
            case "protected_session_terminating",
                 "protected_session_closed",
                 "protected_session_missing":
                return .ended(message: message)
            case "protected_session_failed",
                 "protected_session_unavailable",
                 "protected_session_resolution_failed",
                 "protected_session_timeout",
                 "protected_session_unreachable",
                 "protected_session_upstream_error":
                return .failed(message: message)
            default:
                break
            }

            if apiError.statusCode == 410 {
                return message.localizedLowercase.contains("expired")
                    ? .expired(message: message)
                    : .ended(message: message)
            }
        }

        let normalized = message.localizedLowercase
        if normalized.contains("expired") {
            return .expired(message: message)
        }
        if normalized.contains("no longer available")
            || normalized.contains("was closed")
            || normalized.contains("is ending") {
            return .ended(message: message)
        }
        if normalized.contains("couldn't keep")
            || normalized.contains("was destroyed")
            || normalized.contains("couldn't keep that protected session running") {
            return .failed(message: message)
        }
        return nil
    }

    static func protectedSessionFailurePresentation(
        for error: Error,
        fallback: String
    ) -> ProtectedSessionFailurePresentation? {
        let message = message(for: error, fallback: fallback)

        if let apiError = error as? AmonAPIError {
            switch apiError.backendCode {
            case "protected_session_unavailable",
                 "protected_session_host_not_allowed",
                 "protected_session_navigation_blocked",
                 "protected_session_blocked_address",
                 "protected_session_invalid_url",
                 "protected_session_invalid_port",
                 "protected_session_non_html",
                 "protected_session_response_too_large",
                 "protected_session_parse_failed",
                 "protected_session_starting":
                return .unavailable(message: message)
            case "protected_session_failed",
                 "protected_session_resolution_failed",
                 "protected_session_timeout",
                 "protected_session_unreachable",
                 "protected_session_upstream_error":
                return .failed(message: message)
            default:
                break
            }
        }

        return nil
    }

    static func protectedSessionActionBannerTitle(for error: Error) -> String {
        guard let apiError = error as? AmonAPIError else {
            return "Protected Session"
        }

        switch apiError.backendCode {
        case "protected_session_navigation_blocked",
             "protected_session_blocked_address",
             "protected_session_invalid_url",
             "protected_session_invalid_port",
             "protected_session_non_html",
             "protected_session_response_too_large",
             "protected_session_parse_failed",
             "protected_session_missing_form_id",
             "protected_session_form_not_found",
             "protected_session_missing_link_id",
             "protected_session_link_not_found",
             "protected_session_missing_field_name",
             "protected_session_field_not_found",
             "protected_session_invalid_action",
             "protected_session_empty",
             "protected_session_back_unavailable",
             "protected_session_forward_unavailable":
            return "Couldn't complete remote action"
        default:
            return "Protected Session"
        }
    }

    static func protectedSessionActionBanner(
        code: String?,
        message: String?
    ) -> AmonBanner {
        let bannerTitle: String
        switch code {
        case "protected_session_navigation_blocked",
             "protected_session_blocked_address",
             "protected_session_invalid_url",
             "protected_session_invalid_port",
             "protected_session_non_html",
             "protected_session_response_too_large",
             "protected_session_parse_failed",
             "protected_session_missing_form_id",
             "protected_session_form_not_found",
             "protected_session_missing_link_id",
             "protected_session_link_not_found",
             "protected_session_missing_field_name",
             "protected_session_field_not_found",
             "protected_session_invalid_action",
             "protected_session_empty",
             "protected_session_back_unavailable",
             "protected_session_forward_unavailable":
            bannerTitle = "Couldn't complete remote action"
        default:
            bannerTitle = "Protected Session"
        }

        return AmonBanner(
            tone: .error,
            title: bannerTitle,
            message: message ?? "That protected-session action could not be completed."
        )
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

extension WorkspaceOwnershipSummary {
    var localityBadgeText: String {
        switch localityState {
        case .fullyLocal:
            return "Fully local"
        case .partiallyLocal:
            return "Partially local"
        case .referenceDependent:
            return "Saved references"
        }
    }

    var ownershipSummaryText: String {
        switch localityState {
        case .fullyLocal:
            return "Everything here is backed by readable local copies or owned local artifacts on this device."
        case .partiallyLocal:
            return "This workspace is mostly local, but some saved sources still depend on lightweight references."
        case .referenceDependent:
            return "This workspace still depends mainly on saved source references instead of readable local copies."
        }
    }

    var transitionSummaryText: String? {
        guard canStrengthenFurther else { return nil }

        if linkedSourceOnlyItems > 0 && standaloneSourceOnlyItems > 0 {
            return "\(sourceOnlyItems) saved references can still be strengthened, including \(linkedSourceOnlyItems) linked from owned artifacts."
        }

        if linkedSourceOnlyItems > 0 {
            return "\(linkedSourceOnlyItems) linked source\(linkedSourceOnlyItems == 1 ? "" : "s") behind owned artifacts can still be strengthened."
        }

        return "\(sourceOnlyItems) saved source reference\(sourceOnlyItems == 1 ? "" : "s") can still be strengthened into readable local copies."
    }

    var trustStripItems: [String] {
        var items = [localityBadgeText]

        if ownedReadableItems > 0 {
            items.append("\(ownedReadableItems) saved cop\(ownedReadableItems == 1 ? "y" : "ies")")
        }

        if sourceOnlyItems > 0 {
            items.append("\(sourceOnlyItems) source-only save\(sourceOnlyItems == 1 ? "" : "s")")
        } else if totalItems > 0 {
            items.append("Readable copies saved")
        }

        if ownedLocalArtifacts > 0 {
            items.append("\(ownedLocalArtifacts) local artifact\(ownedLocalArtifacts == 1 ? "" : "s")")
        }

        if artifactsNeedingSourcePromotion > 0 {
            items.append("\(artifactsNeedingSourcePromotion) artifact\(artifactsNeedingSourcePromotion == 1 ? "" : "s") can be strengthened")
        }

        return items
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
