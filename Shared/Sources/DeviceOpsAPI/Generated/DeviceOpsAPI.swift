import Foundation
import HTTPTypes
import OpenAPIRuntime
import OpenAPIURLSession

public enum APIError: Error, Equatable, CustomStringConvertible {
    case invalidResponse
    case decodingFailed
    case httpError(Int)
    case transport(String)

    public var description: String {
        switch self {
        case .invalidResponse: return "Invalid response"
        case .decodingFailed: return "Failed to decode response"
        case .httpError(let code): return "HTTP error \(code)"
        case .transport(let message): return "Transport error: \(message)"
        }
    }
}

public struct DeviceSummary: Codable, Identifiable, Equatable {
    public let id: String
    public let name: String
    public let platform: String
    public let osVersion: String
    public let compliance: String
    public let lastCheckIn: Date
}

public struct DeviceDetail: Codable, Identifiable, Equatable {
    public let id: String
    public let name: String
    public let platform: String
    public let osVersion: String
    public let serialNumber: String
    public let lastCheckIn: Date
    public let complianceSignals: ComplianceSignals
    public let installedApps: [InstalledApp]
}

public struct ComplianceSignals: Codable, Equatable {
    public let fileVaultEnabled: Bool
    public let passcodeEnabled: Bool
    public let edrPresent: Bool
    public let riskyAppsCount: Int
}

public struct InstalledApp: Codable, Identifiable, Equatable {
    public let id: String
    public let name: String
    public let version: String
}

public struct DevicePage: Codable, Equatable {
    public let page: Int
    public let totalPages: Int
    public let items: [DeviceSummary]
}

public struct AssetRecord: Codable, Identifiable, Equatable {
    public let id: String
    public let assetTag: String
    public let serialNumber: String
    public let assignedUser: String
    public let costCenter: String
    public let lifecycleState: String
}

public struct AssetPage: Codable, Equatable {
    public let page: Int
    public let totalPages: Int
    public let items: [AssetRecord]
}

public struct SoftwareItem: Codable, Identifiable, Equatable {
    public let id: String
    public let name: String
    public let version: String
    public let platform: String
    public let required: Bool
}

public struct SoftwarePage: Codable, Equatable {
    public let page: Int
    public let totalPages: Int
    public let items: [SoftwareItem]
}

public struct CommandRequest: Codable, Equatable {
    public let commandType: String
    public let payload: [String: String]?

    public init(commandType: String, payload: [String: String]? = nil) {
        self.commandType = commandType
        self.payload = payload
    }
}

public struct CommandJob: Codable, Identifiable, Equatable {
    public let id: String
    public let status: String
    public let commandType: String
    public let createdAt: Date
    public let completedAt: Date?
    public let failureReason: String?
}

public enum CommandType: String, CaseIterable {
    case queryDeviceInformation
    case querySecurityInfo
    case queryInstalledApps
    case installApplication
}

public struct DeviceOpsClient {
    private let baseURL: URL
    private let authority: String?
    private let token: String?
    private let transport: ClientTransport
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public init(baseURL: URL, token: String? = nil, transport: ClientTransport = URLSessionTransport()) {
        self.baseURL = baseURL
        if let host = baseURL.host {
            if let port = baseURL.port {
                self.authority = "\(host):\(port)"
            } else {
                self.authority = host
            }
        } else {
            self.authority = nil
        }
        self.token = token
        self.transport = transport
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }

    public func listDevices(page: Int, query: String?, platform: String?, compliance: String?) async throws -> DevicePage {
        let response = try await sendRequest(
            method: .get,
            path: "/v1/devices",
            query: [
                URLQueryItem(name: "page", value: String(page)),
                query.map { URLQueryItem(name: "q", value: $0) },
                platform.map { URLQueryItem(name: "platform", value: $0) },
                compliance.map { URLQueryItem(name: "compliance", value: $0) }
            ].compactMap { $0 }
        )
        return try decode(response, as: DevicePage.self)
    }

    public func getDevice(id: String) async throws -> DeviceDetail {
        let response = try await sendRequest(method: .get, path: "/v1/devices/\(id)")
        return try decode(response, as: DeviceDetail.self)
    }

    public func sendCommand(deviceId: String, requestBody: CommandRequest) async throws -> CommandJob {
        let body = try encoder.encode(requestBody)
        let response = try await sendRequest(method: .post, path: "/v1/devices/\(deviceId)/commands", body: body)
        return try decode(response, as: CommandJob.self)
    }

    public func getCommand(jobId: String) async throws -> CommandJob {
        let response = try await sendRequest(method: .get, path: "/v1/commands/\(jobId)")
        return try decode(response, as: CommandJob.self)
    }

    public func listAssets(page: Int, query: String?) async throws -> AssetPage {
        let response = try await sendRequest(
            method: .get,
            path: "/v1/assets",
            query: [
                URLQueryItem(name: "page", value: String(page)),
                query.map { URLQueryItem(name: "q", value: $0) }
            ].compactMap { $0 }
        )
        return try decode(response, as: AssetPage.self)
    }

    public func listSoftware(page: Int, platform: String?) async throws -> SoftwarePage {
        let response = try await sendRequest(
            method: .get,
            path: "/v1/software",
            query: [
                URLQueryItem(name: "page", value: String(page)),
                platform.map { URLQueryItem(name: "platform", value: $0) }
            ].compactMap { $0 }
        )
        return try decode(response, as: SoftwarePage.self)
    }

    public func requestInstall(softwareId: String) async throws -> CommandJob {
        let response = try await sendRequest(method: .post, path: "/v1/software/\(softwareId)/install")
        return try decode(response, as: CommandJob.self)
    }

    private func sendRequest(method: HTTPRequest.Method, path: String, query: [URLQueryItem] = [], body: Data? = nil) async throws -> ResponsePayload {
        var request = HTTPRequest(method: method, scheme: baseURL.scheme, authority: authority, path: pathWithQuery(path: path, query: query))
        var headers = HTTPFields()
        if let token {
            headers[.authorization] = "Bearer \(token)"
        }
        if body != nil {
            headers[.contentType] = "application/json"
        }
        request.headerFields = headers
        let httpBody = body.map { HTTPBody($0) }
        do {
            let (response, responseBody) = try await transport.send(request, body: httpBody, baseURL: baseURL, operationID: path)
            let data: Data?
            if let responseBody {
                data = try await Data(collecting: responseBody, upTo: 5_000_000)
            } else {
                data = nil
            }
            return ResponsePayload(statusCode: response.status.code, data: data)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }
    }

    private func decode<T: Decodable>(_ response: ResponsePayload, as type: T.Type) throws -> T {
        guard (200..<300).contains(response.statusCode) else {
            throw APIError.httpError(response.statusCode)
        }
        guard let data = response.data else {
            throw APIError.invalidResponse
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    private func pathWithQuery(path: String, query: [URLQueryItem]) -> String {
        guard !query.isEmpty else { return path }
        var components = URLComponents()
        components.path = path
        components.queryItems = query
        return components.string ?? path
    }

    private struct ResponsePayload {
        let statusCode: Int
        let data: Data?
    }
}
