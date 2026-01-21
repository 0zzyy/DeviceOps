import Foundation
import NIO
import NIOConcurrencyHelpers
import NIOHTTP1
import DeviceOpsCore

final class MockDataStore: @unchecked Sendable {
    private let lock = NIOLock()
    private var devices: [DeviceDetailInfo]
    private var deviceSummaries: [Device]
    private var assets: [Asset]
    private var software: [Software]
    private var commandJobs: [String: CommandJobInfo]

    init() {
        let platforms: [Platform] = [.macOS, .iOS, .iPadOS, .tvOS, .visionOS]
        var summaries: [Device] = []
        var details: [DeviceDetailInfo] = []
        for index in 1...2000 {
            let platform = platforms[index % platforms.count]
            let compliance: ComplianceStatus = index % 5 == 0 ? .noncompliant : .compliant
            let id = "D\(String(format: "%04d", index))"
            let lastCheckIn = Date().addingTimeInterval(TimeInterval(-index * 300))
            let summary = Device(
                id: id,
                name: "Device \(index)",
                platform: platform,
                osVersion: "\(platform == .macOS ? "14" : "17").\(index % 5)",
                compliance: compliance,
                lastCheckIn: lastCheckIn
            )
            summaries.append(summary)
            let signals = ComplianceSignals(
                fileVaultEnabled: platform == .macOS ? index % 4 != 0 : true,
                passcodeEnabled: index % 6 != 0,
                edrPresent: index % 7 != 0,
                riskyAppsCount: index % 3 == 0 ? 2 : 0
            )
            let detail = DeviceDetailInfo(
                id: id,
                name: summary.name,
                platform: platform,
                osVersion: summary.osVersion,
                serialNumber: "SERIAL-\(id)",
                lastCheckIn: lastCheckIn,
                complianceSignals: signals,
                installedApps: [
                    InstalledApp(id: "app-\(index)-1", name: "DeviceOps Agent", version: "1.\(index % 4)"),
                    InstalledApp(id: "app-\(index)-2", name: "SecureConnect", version: "2.\(index % 5)")
                ]
            )
            details.append(detail)
        }
        var assets: [Asset] = []
        for index in 1...500 {
            let serial = index % 4 == 0 ? "SERIAL-D\(String(format: "%04d", index))" : "SERIAL-X\(index)"
            assets.append(Asset(
                id: "A\(index)",
                assetTag: "TAG-\(index)",
                serialNumber: serial,
                assignedUser: "User \(index)",
                costCenter: "CC-\(100 + (index % 5))",
                lifecycleState: index % 10 == 0 ? "retired" : "in-use"
            ))
        }
        let software = (1...120).map { index -> Software in
            let platform = platforms[index % platforms.count]
            return Software(
                id: "S\(index)",
                name: "App \(index)",
                version: "\(index % 5).\(index % 10)",
                platform: platform,
                required: index % 3 == 0
            )
        }
        self.devices = details
        self.deviceSummaries = summaries
        self.assets = assets
        self.software = software
        self.commandJobs = [:]
    }

    func listDevices(page: Int, pageSize: Int, query: String?, platform: Platform?, compliance: ComplianceStatus?) -> Page<Device> {
        lock.withLock {
            let filtered = deviceSummaries.filter { device in
                let matchesQuery = query.map { device.name.localizedCaseInsensitiveContains($0) || device.id.localizedCaseInsensitiveContains($0) } ?? true
                let matchesPlatform = platform.map { device.platform == $0 } ?? true
                let matchesCompliance = compliance.map { device.compliance == $0 } ?? true
                return matchesQuery && matchesPlatform && matchesCompliance
            }
            let start = max((page - 1) * pageSize, 0)
            let end = min(start + pageSize, filtered.count)
            let items = start < end ? Array(filtered[start..<end]) : []
            return Page(page: page, totalPages: Int(ceil(Double(filtered.count) / Double(pageSize))), items: items)
        }
    }

    func deviceDetail(id: String) -> DeviceDetailInfo? {
        lock.withLock { devices.first(where: { $0.id == id }) }
    }

    func listAssets(page: Int, pageSize: Int, query: String?) -> Page<Asset> {
        lock.withLock {
            let filtered = assets.filter { asset in
                query.map { asset.assetTag.localizedCaseInsensitiveContains($0) || asset.serialNumber.localizedCaseInsensitiveContains($0) } ?? true
            }
            let start = max((page - 1) * pageSize, 0)
            let end = min(start + pageSize, filtered.count)
            let items = start < end ? Array(filtered[start..<end]) : []
            return Page(page: page, totalPages: Int(ceil(Double(filtered.count) / Double(pageSize))), items: items)
        }
    }

    func listSoftware(page: Int, pageSize: Int, platform: Platform?) -> Page<Software> {
        lock.withLock {
            let filtered = software.filter { item in
                platform.map { item.platform == $0 } ?? true
            }
            let start = max((page - 1) * pageSize, 0)
            let end = min(start + pageSize, filtered.count)
            let items = start < end ? Array(filtered[start..<end]) : []
            return Page(page: page, totalPages: Int(ceil(Double(filtered.count) / Double(pageSize))), items: items)
        }
    }

    func createJob(commandType: String) -> CommandJobInfo {
        lock.withLock {
            let jobId = UUID().uuidString
            let job = CommandJobInfo(
                id: jobId,
                status: .queued,
                commandType: commandType,
                createdAt: Date(),
                completedAt: nil,
                failureReason: nil
            )
            commandJobs[jobId] = job
            return job
        }
    }

    func job(id: String) -> CommandJobInfo? {
        lock.withLock { commandJobs[id] }
    }

    func updateJob(id: String, status: CommandStatus, failureReason: String?) {
        lock.withLock {
            guard let existing = commandJobs[id] else { return }
            let updated = CommandJobInfo(
                id: existing.id,
                status: status,
                commandType: existing.commandType,
                createdAt: existing.createdAt,
                completedAt: status == .succeeded || status == .failed ? Date() : nil,
                failureReason: failureReason
            )
            commandJobs[id] = updated
        }
    }
}

final class MockServerHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    private var buffer: ByteBuffer?
    private var requestHead: HTTPRequestHead?
    private let store: MockDataStore
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(store: MockDataStore) {
        self.store = store
        self.encoder.dateEncodingStrategy = .iso8601
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let part = unwrapInboundIn(data)
        switch part {
        case .head(let head):
            requestHead = head
            buffer = context.channel.allocator.buffer(capacity: 0)
        case .body(var body):
            buffer?.writeBuffer(&body)
        case .end:
            handleRequest(context: context)
            requestHead = nil
            buffer = nil
        }
    }

    private func handleRequest(context: ChannelHandlerContext) {
        guard let head = requestHead else { return }
        let path = head.uri.split(separator: "?").first.map(String.init) ?? head.uri
        let queryItems = URLComponents(string: "http://localhost" + head.uri)?.queryItems ?? []
        let page = Int(queryItems.first(where: { $0.name == "page" })?.value ?? "1") ?? 1
        let pageSize = 50
        let query = queryItems.first(where: { $0.name == "q" })?.value
        let platform = queryItems.first(where: { $0.name == "platform" })?.value.flatMap(Platform.init(rawValue:))
        let compliance = queryItems.first(where: { $0.name == "compliance" })?.value.flatMap(ComplianceStatus.init(rawValue:))

        switch (head.method, path) {
        case (.GET, "/v1/devices"):
            let response = store.listDevices(page: page, pageSize: pageSize, query: query, platform: platform, compliance: compliance)
            sendJSON(response, status: .ok, context: context)
        case (.GET, let path) where path.starts(with: "/v1/devices/"):
            let id = path.replacingOccurrences(of: "/v1/devices/", with: "")
            if let device = store.deviceDetail(id: id) {
                sendJSON(device, status: .ok, context: context)
            } else {
                sendEmpty(status: .notFound, context: context)
            }
        case (.POST, let path) where path.starts(with: "/v1/devices/") && path.hasSuffix("/commands"):
            let commandType = decodeCommandType() ?? "command"
            let job = store.createJob(commandType: commandType)
            scheduleJobCompletion(jobId: job.id)
            sendJSON(job, status: .accepted, context: context)
        case (.GET, let path) where path.starts(with: "/v1/commands/"):
            let jobId = path.replacingOccurrences(of: "/v1/commands/", with: "")
            if let job = store.job(id: jobId) {
                sendJSON(job, status: .ok, context: context)
            } else {
                sendEmpty(status: .notFound, context: context)
            }
        case (.GET, "/v1/assets"):
            let response = store.listAssets(page: page, pageSize: pageSize, query: query)
            sendJSON(response, status: .ok, context: context)
        case (.GET, "/v1/software"):
            let response = store.listSoftware(page: page, pageSize: pageSize, platform: platform)
            sendJSON(response, status: .ok, context: context)
        case (.POST, let path) where path.starts(with: "/v1/software/") && path.hasSuffix("/install"):
            let job = store.createJob(commandType: "installApplication")
            scheduleJobCompletion(jobId: job.id)
            sendJSON(job, status: .accepted, context: context)
        default:
            sendEmpty(status: .notFound, context: context)
        }
    }

    private func scheduleJobCompletion(jobId: String) {
        let delay = UInt64(500_000_000 + (UInt64(abs(jobId.hashValue)) % 1_500_000_000))
        let store = store
        Task.detached {
            store.updateJob(id: jobId, status: .inProgress, failureReason: nil)
            try await Task.sleep(nanoseconds: delay)
            let shouldFail = abs(jobId.hashValue) % 5 == 0
            store.updateJob(id: jobId, status: shouldFail ? .failed : .succeeded, failureReason: shouldFail ? "Agent timeout" : nil)
        }
    }

    private func sendJSON<T: Encodable>(_ payload: T, status: HTTPResponseStatus, context: ChannelHandlerContext) {
        var buffer = context.channel.allocator.buffer(capacity: 0)
        if let data = try? encoder.encode(payload) {
            buffer.writeBytes(data)
        }
        let headers = HTTPHeaders([
            ("Content-Type", "application/json")
        ])
        context.write(wrapOutboundOut(.head(.init(version: .http1_1, status: status, headers: headers))), promise: nil)
        context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
        context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
    }

    private func sendEmpty(status: HTTPResponseStatus, context: ChannelHandlerContext) {
        context.write(wrapOutboundOut(.head(.init(version: .http1_1, status: status))), promise: nil)
        context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
    }

    private func decodeCommandType() -> String? {
        guard let buffer else { return nil }
        let data = Data(buffer.readableBytesView)
        guard !data.isEmpty else { return nil }
        struct Payload: Decodable { let commandType: String }
        return try? decoder.decode(Payload.self, from: data).commandType
    }
}

@main
struct DeviceOpsMockServer {
    static func main() throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        let store = MockDataStore()

        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline().flatMap {
                    channel.pipeline.addHandler(MockServerHandler(store: store))
                }
            }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)

        let channel = try bootstrap.bind(host: "0.0.0.0", port: 8080).wait()
        print("Mock server running on http://localhost:8080")
        try channel.closeFuture.wait()
        try group.syncShutdownGracefully()
    }
}
