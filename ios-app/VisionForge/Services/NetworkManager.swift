//
//  NetworkManager.swift
//  Network layer management for Claude Code mobile client.
//
//  Provides centralized network configuration, connection monitoring, and service coordination.
//  Handles network reachability, configuration switching, and service lifecycle management.
//

import Foundation
import Network
import Observation

// MARK: - Network Manager

@MainActor
@Observable
class NetworkManager {

    // MARK: - Observable Properties

    var isNetworkAvailable: Bool = true
    var connectionType: NWInterface.InterfaceType = .other
    var activeConfig: BackendConfig
    var claudeService: ClaudeService

    // MARK: - Private Properties

    private let pathMonitor: NWPathMonitor
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    private var pathUpdateHandler: ((NWPath) -> Void)?

    // MARK: - Initialization

    init(config: BackendConfig? = nil) {
        // Use provided config or a temporary placeholder
        // The app will show setup flow if no saved config exists
        let initialConfig = config ?? BackendConfig(
            name: "Unconfigured",
            host: "localhost",
            port: 8000,
            scheme: "http"
        )

        self.activeConfig = initialConfig
        self.pathMonitor = NWPathMonitor()

        // Initialize Claude service with proper dependencies
        let baseURL = initialConfig.baseURL ?? URL(string: "http://localhost:8000")!
        let networkClient = ClaudeNetworkClient(baseURL: baseURL)
        let sessionDataSource = SessionAPIClient(networkClient: networkClient)
        let streamingService = ClaudeStreamingService(networkClient: networkClient)
        let queryService = ClaudeQueryService(
            networkClient: networkClient,
            streamingService: streamingService
        )

        self.claudeService = ClaudeService(
            networkClient: networkClient,
            sessionDataSource: sessionDataSource,
            streamingService: streamingService,
            queryService: queryService
        )

        setupNetworkMonitoring()
        startMonitoring()
    }

    deinit {
        pathMonitor.cancel()
    }

    // MARK: - Network Monitoring

    private func setupNetworkMonitoring() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.handleNetworkPath(path)
            }
        }
    }

    private func startMonitoring() {
        pathMonitor.start(queue: monitorQueue)
    }

    private func handleNetworkPath(_ path: NWPath) {
        // Update network availability
        isNetworkAvailable = path.status == .satisfied

        // Update connection type
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .wiredEthernet
        } else {
            connectionType = .other
        }

        // Handle network availability changes
        if isNetworkAvailable {
            handleNetworkAvailable()
        } else {
            handleNetworkUnavailable()
        }
    }

    private func handleNetworkAvailable() {
        print("🌐 Network became available (\(connectionType.displayName))")

        // Reconnect Claude service if needed
        if !claudeService.isConnected {
            Task {
                do {
                    try await claudeService.connect()
                } catch {
                    print("⚠️ Failed to reconnect Claude service: \(error)")
                }
            }
        }
    }

    private func handleNetworkUnavailable() {
        print("🚫 Network became unavailable")
        Task {
            await claudeService.disconnect()
        }
    }

    // MARK: - Configuration Management

    func updateConfiguration(_ newConfig: BackendConfig) async {
        // Only update if configuration actually changed
        if activeConfig.host == newConfig.host &&
           activeConfig.port == newConfig.port &&
           activeConfig.scheme == newConfig.scheme {
            return
        }

        // Disconnect current service if exists
        await claudeService.disconnect()

        // Update configuration
        activeConfig = newConfig

        // Create new service with updated config
        guard let baseURL = newConfig.baseURL else {
            print("⚠️ Invalid network configuration - no base URL")
            return
        }

        // Recreate Claude service with new URL
        let networkClient = ClaudeNetworkClient(baseURL: baseURL)
        let sessionDataSource = SessionAPIClient(networkClient: networkClient)
        let streamingService = ClaudeStreamingService(networkClient: networkClient)
        let queryService = ClaudeQueryService(
            networkClient: networkClient,
            streamingService: streamingService
        )

        claudeService = ClaudeService(
            networkClient: networkClient,
            sessionDataSource: sessionDataSource,
            streamingService: streamingService,
            queryService: queryService
        )

        // Reconnect if network is available
        if isNetworkAvailable {
            do {
                try await claudeService.connect()
            } catch {
                print("⚠️ Failed to connect with new configuration: \(error)")
            }
        }
    }

    // MARK: - Health Check

    func performHealthCheck() async -> Bool {
        guard isNetworkAvailable else {
            return false
        }

        do {
            return try await claudeService.checkHealth()
        } catch {
            print("⚠️ Health check failed: \(error)")
            return false
        }
    }

    // MARK: - Service Access

    func getClaudeService() -> ClaudeService {
        return claudeService
    }
}

// MARK: - Backend Configuration

struct BackendConfig: Identifiable, Codable, Hashable {
    var id = UUID()
    let name: String
    let host: String
    let port: Int
    let scheme: String
    let timeout: TimeInterval

    enum CodingKeys: String, CodingKey {
        case id, name, host, port, scheme, timeout
    }

    var baseURL: URL? {
        return URL(string: "\(scheme)://\(host):\(port)")
    }

    var webSocketURL: URL? {
        let wsScheme = scheme == "https" ? "wss" : "ws"
        return URL(string: "\(wsScheme)://\(host):\(port)")
    }

    init(name: String, host: String, port: Int, scheme: String = "http", timeout: TimeInterval = 30.0) {
        self.name = name
        self.host = host
        self.port = port
        self.scheme = scheme
        self.timeout = timeout
    }

    // Example configurations for user reference only
    static func exampleLocal() -> BackendConfig {
        BackendConfig(
            name: "Local Development",
            host: "127.0.0.1",
            port: 8000,
            scheme: "http"
        )
    }

    static func exampleProduction() -> BackendConfig {
        BackendConfig(
            name: "Production Server",
            host: "api.yourserver.com",
            port: 443,
            scheme: "https"
        )
    }
}

// MARK: - Connection Type Extensions

extension NWInterface.InterfaceType {
    var displayName: String {
        switch self {
        case .wifi:
            return "Wi-Fi"
        case .cellular:
            return "Cellular"
        case .wiredEthernet:
            return "Ethernet"
        case .loopback:
            return "Loopback"
        case .other:
            return "Other"
        @unknown default:
            return "Unknown"
        }
    }

    var icon: String {
        switch self {
        case .wifi:
            return "wifi"
        case .cellular:
            return "antenna.radiowaves.left.and.right"
        case .wiredEthernet:
            return "cable.connector"
        case .loopback:
            return "arrow.triangle.2.circlepath"
        case .other:
            return "network"
        @unknown default:
            return "questionmark.diamond"
        }
    }
}