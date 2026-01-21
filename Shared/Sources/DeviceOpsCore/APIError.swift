import Foundation

public enum DeviceOpsError: Error, Equatable, LocalizedError {
    case networkUnavailable
    case serverUnavailable
    case unauthorized
    case notFound
    case decodingFailed
    case unexpectedResponse
    case rateLimited
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .networkUnavailable: return "Network unavailable"
        case .serverUnavailable: return "Server unavailable"
        case .unauthorized: return "Unauthorized"
        case .notFound: return "Not found"
        case .decodingFailed: return "Failed to decode response"
        case .unexpectedResponse: return "Unexpected response"
        case .rateLimited: return "Rate limited"
        case .unknown(let message): return message
        }
    }
}
