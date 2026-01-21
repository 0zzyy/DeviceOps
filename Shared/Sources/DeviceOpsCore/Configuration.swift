import Foundation

public struct DeviceOpsConfig: Equatable {
    public let baseURL: URL
    public let token: String?

    public init(baseURL: URL, token: String?) {
        self.baseURL = baseURL
        self.token = token
    }

    public static func load() -> DeviceOpsConfig {
        let env = ProcessInfo.processInfo.environment
        if let urlString = env["DEVICEOPS_BASE_URL"], let url = URL(string: urlString) {
            return DeviceOpsConfig(baseURL: url, token: env["DEVICEOPS_TOKEN"])
        }
        let configURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Configs/deviceops.json")
        if let data = try? Data(contentsOf: configURL),
           let config = try? JSONDecoder().decode(ConfigFile.self, from: data),
           let url = URL(string: config.baseURL) {
            return DeviceOpsConfig(baseURL: url, token: config.token)
        }
        return DeviceOpsConfig(baseURL: URL(string: "http://localhost:8080")!, token: nil)
    }

    private struct ConfigFile: Codable {
        let baseURL: String
        let token: String?
    }
}
