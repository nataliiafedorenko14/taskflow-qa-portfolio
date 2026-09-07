import Foundation

/// Errors surfaced by the API client to the UI layer.
enum APIError: Error, LocalizedError {
    case invalidURL
    case badStatus(Int, String)
    case decodingFailed(String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid server address."
        case .badStatus(let code, let message):
            return message.isEmpty ? "Server error (\(code))" : message
        case .decodingFailed(let m): return "Failed to read server response: \(m)"
        case .transport(let m): return "Network error: \(m)"
        }
    }

    /// True when the error is one the UI should show a Retry button for.
    var isRetryable: Bool {
        switch self {
        case .transport, .badStatus(500, _), .badStatus(409, _):
            return true
        default:
            return false
        }
    }
}

/// Wrapper the server returns on errors: {"detail": "..."}
struct APIErrorBody: Decodable {
    let detail: String
}
