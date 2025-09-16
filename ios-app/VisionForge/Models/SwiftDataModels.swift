//
//  SwiftDataModels.swift
//  SwiftData models for persistent storage of sessions and message history.
//
//  Provides offline access, session recovery, and conversation persistence across app launches.
//

import Foundation
import SwiftData
import Combine

// MARK: - Persisted Session Model

@Model
final class PersistedSession {
    @Attribute(.unique) var id: String
    var name: String
    var createdAt: Date
    var lastAccessedAt: Date
    var status: String
    var userId: String

    @Relationship(deleteRule: .cascade, inverse: \PersistedMessage.session)
    var messages: [PersistedMessage] = []

    @Relationship(deleteRule: .nullify)
    var configuration: PersistedConfiguration?

    // Metadata stored as Data (JSON encoded)
    var metadataData: Data?

    var metadata: [String: String]? {
        get {
            guard let data = metadataData else { return nil }
            return try? JSONDecoder().decode([String: String].self, from: data)
        }
        set {
            metadataData = try? JSONEncoder().encode(newValue)
        }
    }

    init(
        id: String = UUID().uuidString,
        name: String,
        createdAt: Date = Date(),
        lastAccessedAt: Date = Date(),
        status: String = "active",
        userId: String,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.lastAccessedAt = lastAccessedAt
        self.status = status
        self.userId = userId
        self.metadata = metadata
    }

    // MARK: - Conversion Methods

    func toSessionResponse() -> SessionResponse {
        SessionResponse(
            sessionId: id,
            userId: userId,
            sessionName: name,
            status: SessionStatus(rawValue: status) ?? .active,
            messages: messages.sorted(by: { $0.timestamp < $1.timestamp }).map { $0.toClaudeMessage() },
            createdAt: createdAt,
            updatedAt: lastAccessedAt,
            messageCount: messages.count,
            context: [:]
        )
    }

    static func from(_ response: SessionResponse) -> PersistedSession {
        let session = PersistedSession(
            id: response.sessionId,
            name: response.sessionName ?? "Untitled Session",
            createdAt: response.createdAt,
            lastAccessedAt: response.updatedAt,
            status: response.status.rawValue,
            userId: response.userId
        )

        // Convert messages
        session.messages = response.messages.map { PersistedMessage.from($0, sessionId: response.sessionId) }

        return session
    }
}

// MARK: - Persisted Message Model

@Model
final class PersistedMessage {
    @Attribute(.unique) var id: String
    var content: String
    var role: String
    var timestamp: Date
    var sessionId: String

    var session: PersistedSession?

    // Store metadata as Data (JSON encoded)
    var metadataData: Data?

    var metadata: [String: AnyCodable]? {
        get {
            guard let data = metadataData else { return nil }
            return try? JSONDecoder().decode([String: AnyCodable].self, from: data)
        }
        set {
            metadataData = try? JSONEncoder().encode(newValue)
        }
    }

    init(
        id: String = UUID().uuidString,
        content: String,
        role: String,
        timestamp: Date = Date(),
        sessionId: String,
        metadata: [String: AnyCodable]? = nil
    ) {
        self.id = id
        self.content = content
        self.role = role
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.metadata = metadata
    }

    // MARK: - Conversion Methods

    func toClaudeMessage() -> ClaudeMessage {
        ClaudeMessage(
            id: id,
            content: content,
            role: MessageRole(rawValue: role) ?? .assistant,
            timestamp: timestamp,
            sessionId: sessionId,
            metadata: metadata
        )
    }

    static func from(_ message: ClaudeMessage, sessionId: String) -> PersistedMessage {
        PersistedMessage(
            id: message.id,
            content: message.content,
            role: message.role.rawValue,
            timestamp: message.timestamp,
            sessionId: sessionId,
            metadata: message.metadata
        )
    }
}

// MARK: - Persisted Configuration Model

@Model
final class PersistedConfiguration {
    @Attribute(.unique) var id: String
    var name: String
    var host: String
    var port: Int
    var scheme: String
    var timeout: Double
    var isActive: Bool
    var createdAt: Date
    var lastUsedAt: Date

    @Relationship(deleteRule: .nullify)
    var sessions: [PersistedSession] = []

    init(
        id: String = UUID().uuidString,
        name: String,
        host: String,
        port: Int,
        scheme: String = "http",
        timeout: Double = 30.0,
        isActive: Bool = false,
        createdAt: Date = Date(),
        lastUsedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.scheme = scheme
        self.timeout = timeout
        self.isActive = isActive
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
    }

    // MARK: - Conversion Methods

    func toBackendConfig() -> BackendConfig {
        BackendConfig(
            name: name,
            host: host,
            port: port,
            scheme: scheme,
            timeout: timeout
        )
    }

    static func from(_ config: BackendConfig) -> PersistedConfiguration {
        PersistedConfiguration(
            name: config.name,
            host: config.host,
            port: config.port,
            scheme: config.scheme,
            timeout: config.timeout
        )
    }
}

// MARK: - SwiftData Manager

@MainActor
final class PersistenceManager: ObservableObject {
    private let container: ModelContainer
    private let context: ModelContext

    @Published var sessions: [PersistedSession] = []
    @Published var configurations: [PersistedConfiguration] = []

    init() throws {
        let schema = Schema([
            PersistedSession.self,
            PersistedMessage.self,
            PersistedConfiguration.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )

        container = try ModelContainer(
            for: schema,
            configurations: [modelConfiguration]
        )

        context = container.mainContext

        // Enable autosave
        context.autosaveEnabled = true

        // Load initial data
        loadSessions()
        loadConfigurations()
    }

    // MARK: - Session Management

    func loadSessions() {
        let descriptor = FetchDescriptor<PersistedSession>(
            sortBy: [SortDescriptor(\.lastAccessedAt, order: .reverse)]
        )

        do {
            sessions = try context.fetch(descriptor)
        } catch {
            print("Failed to load sessions: \\(error)")
        }
    }

    func saveSession(_ response: SessionResponse) {
        // Check if session already exists
        let predicate = #Predicate<PersistedSession> { session in
            session.id == response.sessionId
        }

        let descriptor = FetchDescriptor<PersistedSession>(predicate: predicate)

        do {
            let existingSessions = try context.fetch(descriptor)

            if let existing = existingSessions.first {
                // Update existing session
                existing.lastAccessedAt = Date()
                existing.status = response.status.rawValue

                // Update messages
                for message in response.messages {
                    if !existing.messages.contains(where: { $0.id == message.id }) {
                        let persistedMessage = PersistedMessage.from(message, sessionId: response.sessionId)
                        existing.messages.append(persistedMessage)
                    }
                }
            } else {
                // Create new session
                let newSession = PersistedSession.from(response)
                context.insert(newSession)
            }

            try context.save()
            loadSessions()
        } catch {
            print("Failed to save session: \\(error)")
        }
    }

    func deleteSession(_ sessionId: String) {
        let predicate = #Predicate<PersistedSession> { session in
            session.id == sessionId
        }

        do {
            try context.delete(model: PersistedSession.self, where: predicate)
            try context.save()
            loadSessions()
        } catch {
            print("Failed to delete session: \\(error)")
        }
    }

    func getRecentSessions(limit: Int = 10) -> [PersistedSession] {
        return Array(sessions.prefix(limit))
    }

    // MARK: - Message Management

    func saveMessage(_ message: ClaudeMessage, to sessionId: String) {
        let sessionPredicate = #Predicate<PersistedSession> { session in
            session.id == sessionId
        }

        do {
            let descriptor = FetchDescriptor<PersistedSession>(predicate: sessionPredicate)
            let sessions = try context.fetch(descriptor)

            if let session = sessions.first {
                let persistedMessage = PersistedMessage.from(message, sessionId: sessionId)
                session.messages.append(persistedMessage)
                session.lastAccessedAt = Date()

                try context.save()
            }
        } catch {
            print("Failed to save message: \\(error)")
        }
    }

    func getMessages(for sessionId: String) -> [ClaudeMessage] {
        let predicate = #Predicate<PersistedMessage> { message in
            message.sessionId == sessionId
        }

        let descriptor = FetchDescriptor<PersistedMessage>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestamp)]
        )

        do {
            let messages = try context.fetch(descriptor)
            return messages.map { $0.toClaudeMessage() }
        } catch {
            print("Failed to fetch messages: \\(error)")
            return []
        }
    }

    // MARK: - Configuration Management

    func loadConfigurations() {
        let descriptor = FetchDescriptor<PersistedConfiguration>(
            sortBy: [SortDescriptor(\.lastUsedAt, order: .reverse)]
        )

        do {
            configurations = try context.fetch(descriptor)
        } catch {
            print("Failed to load configurations: \\(error)")
        }
    }

    func saveConfiguration(_ config: BackendConfig, setActive: Bool = false) {
        // Deactivate other configs if setting this one as active
        if setActive {
            for existingConfig in configurations {
                existingConfig.isActive = false
            }
        }

        let persistedConfig = PersistedConfiguration.from(config)
        persistedConfig.isActive = setActive

        context.insert(persistedConfig)

        do {
            try context.save()
            loadConfigurations()
        } catch {
            print("Failed to save configuration: \\(error)")
        }
    }

    func getActiveConfiguration() -> BackendConfig? {
        return configurations.first(where: { $0.isActive })?.toBackendConfig()
    }

    func deleteConfiguration(_ configId: String) {
        let predicate = #Predicate<PersistedConfiguration> { config in
            config.id == configId
        }

        do {
            try context.delete(model: PersistedConfiguration.self, where: predicate)
            try context.save()
            loadConfigurations()
        } catch {
            print("Failed to delete configuration: \\(error)")
        }
    }

    // MARK: - Cleanup

    func cleanupOldSessions(daysToKeep: Int = 30) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -daysToKeep, to: Date()) ?? Date()

        let predicate = #Predicate<PersistedSession> { session in
            session.lastAccessedAt < cutoffDate
        }

        do {
            try context.delete(model: PersistedSession.self, where: predicate)
            try context.save()
            loadSessions()
        } catch {
            print("Failed to cleanup old sessions: \\(error)")
        }
    }
}