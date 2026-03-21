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
    private struct ServerDetailEnvelope: Decodable {
        let detail: String
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
                if statusCode == 503 {
                    return detail ?? "Amon can't reach that service right now. Check that the backend is running."
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
        if let envelope = try? JSONDecoder().decode(ServerDetailEnvelope.self, from: data) {
            return envelope.detail
        }
        return body.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
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
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
