//
//  SessionPersistenceService.swift
//  CoreData persistence service for session management.
//
//  Handles local session persistence, conversation history storage, and offline session management
//  using CoreData for production stability and performance with SessionManager integration.
//

import Foundation
import CoreData
import Observation

// MARK: - CoreData Model Definitions (Production-Stable)

/// CoreData model for persistent session storage
@objc(PersistedSession)
public class PersistedSession: NSManagedObject {
    @NSManaged public var sessionId: String
    @NSManaged public var userId: String
    @NSManaged public var sessionName: String?
    @NSManaged public var workingDirectory: String?
    @NSManaged public var status: String
    @NSManaged public var createdAt: Date
    @NSManaged public var lastActiveAt: Date
    @NSManaged public var messageCount: Int32
    @NSManaged public var conversationData: Data?
    @NSManaged public var sessionManagerMetadata: Data?
    @NSManaged public var messages: NSSet?
}

/// CoreData model for persistent message storage
@objc(PersistedMessage)
public class PersistedMessage: NSManagedObject {
    @NSManaged public var messageId: String
    @NSManaged public var sessionId: String
    @NSManaged public var role: String
    @NSManaged public var content: String
    @NSManaged public var timestamp: Date
    @NSManaged public var metadata: Data?
    @NSManaged public var session: PersistedSession?
}

// MARK: - Fetch Request Extensions

extension PersistedSession {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<PersistedSession> {
        return NSFetchRequest<PersistedSession>(entityName: "PersistedSession")
    }
}

extension PersistedMessage {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<PersistedMessage> {
        return NSFetchRequest<PersistedMessage>(entityName: "PersistedMessage")
    }
}

// MARK: - Persistence Service Protocol

protocol SessionPersistenceServiceProtocol {
    func saveSession(_ session: SessionManagerResponse) async throws
    func loadSession(sessionId: String) async throws -> SessionManagerResponse?
    func loadRecentSessions(limit: Int) async throws -> [SessionManagerResponse]
    func loadUserSessions(userId: String, limit: Int) async throws -> [SessionManagerResponse]
    func deleteSession(sessionId: String) async throws
    func saveConversationMessage(_ message: ConversationMessage) async throws
    func loadConversationHistory(sessionId: String, limit: Int) async throws -> [ConversationMessage]
    func clearOldSessions(olderThan: Date) async throws
    func getStorageStatistics() async throws -> SessionStorageStats
}

// MARK: - Storage Statistics

struct SessionStorageStats {
    let totalSessions: Int
    let totalMessages: Int
    let storageUsedMB: Double
    let oldestSessionDate: Date?
    let newestSessionDate: Date?
}

// MARK: - Persistence Errors

enum SessionPersistenceError: LocalizedError {
    case coreDataNotInitialized
    case sessionNotFound(String)
    case saveFailure(Error)
    case loadFailure(Error)
    case invalidSessionData
    case storageQuotaExceeded

    var errorDescription: String? {
        switch self {
        case .coreDataNotInitialized:
            return "CoreData stack not initialized"
        case .sessionNotFound(let sessionId):
            return "Session not found: \(sessionId)"
        case .saveFailure(let error):
            return "Failed to save session: \(error.localizedDescription)"
        case .loadFailure(let error):
            return "Failed to load session: \(error.localizedDescription)"
        case .invalidSessionData:
            return "Invalid session data format"
        case .storageQuotaExceeded:
            return "Local storage quota exceeded"
        }
    }
}

// MARK: - Session Persistence Service Implementation

@MainActor
@Observable
class SessionPersistenceService: SessionPersistenceServiceProtocol {

    // MARK: - Observable Properties

    var isInitialized: Bool = false
    var storageStats: SessionStorageStats?

    // MARK: - Private Properties

    private var persistentContainer: NSPersistentContainer?
    private let modelName = "SessionDataModel"
    private let maxStorageMB: Double = 500.0  // 500MB storage limit
    private let maxSessionsPerUser = 100
    private let maxMessagesPerSession = 1000

    // JSON coders for complex data serialization
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - Initialization

    init() {
        setupDateFormatters()
        Task {
            await initializeCoreDataStack()
        }
    }

    private func setupDateFormatters() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

        encoder.dateEncodingStrategy = .formatted(dateFormatter)
        decoder.dateDecodingStrategy = .formatted(dateFormatter)
    }

    private func initializeCoreDataStack() async {
        guard persistentContainer == nil else { return }

        persistentContainer = NSPersistentContainer(name: modelName)

        // Configure persistent store for performance
        if let storeDescription = persistentContainer?.persistentStoreDescriptions.first {
            storeDescription.shouldInferMappingModelAutomatically = true
            storeDescription.shouldMigrateStoreAutomatically = true
            storeDescription.setValue("WAL" as NSString, forPragmaNamed: "journal_mode")
            storeDescription.setValue("1" as NSString, forPragmaNamed: "synchronous")
        }

        persistentContainer?.loadPersistentStores { [weak self] _, error in
            if let error = error {
                print("⚠️ CoreData loading error: \(error)")
                return
            }

            Task { @MainActor in
                self?.isInitialized = true
                await self?.updateStorageStatistics()
                print("✅ SessionPersistenceService initialized successfully")
            }
        }
    }

    // MARK: - Context Management

    private var viewContext: NSManagedObjectContext {
        guard let context = persistentContainer?.viewContext else {
            fatalError("CoreData stack not initialized")
        }
        return context
    }

    private func newBackgroundContext() -> NSManagedObjectContext {
        guard let container = persistentContainer else {
            fatalError("CoreData stack not initialized")
        }
        return container.newBackgroundContext()
    }

    // MARK: - Session Management

    func saveSession(_ session: SessionManagerResponse) async throws {
        guard isInitialized else {
            throw SessionPersistenceError.coreDataNotInitialized
        }

        try await withCheckedThrowingContinuation { continuation in
            let backgroundContext = newBackgroundContext()
            backgroundContext.perform {
                do {
                    // Check if session already exists
                    let fetchRequest: NSFetchRequest<PersistedSession> = PersistedSession.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "sessionId == %@", session.sessionId)

                    let existingSessions = try backgroundContext.fetch(fetchRequest)
                    let persistedSession = existingSessions.first ?? PersistedSession(context: backgroundContext)

                    // Update session properties
                    persistedSession.sessionId = session.sessionId
                    persistedSession.userId = session.userId
                    persistedSession.sessionName = session.sessionName
                    persistedSession.workingDirectory = session.workingDirectory
                    persistedSession.status = session.status.rawValue
                    persistedSession.createdAt = session.createdAt
                    persistedSession.lastActiveAt = session.lastActiveAt
                    persistedSession.messageCount = Int32(session.messageCount)

                    // Serialize conversation history and session manager stats
                    if let conversationHistory = session.conversationHistory {
                        persistedSession.conversationData = try self.encoder.encode(conversationHistory)
                    }

                    if let stats = session.sessionManagerStats {
                        persistedSession.sessionManagerMetadata = try self.encoder.encode(stats)
                    }

                    try backgroundContext.save()
                    continuation.resume()

                } catch {
                    continuation.resume(throwing: SessionPersistenceError.saveFailure(error))
                }
            }
        }

        await updateStorageStatistics()
    }

    func loadSession(sessionId: String) async throws -> SessionManagerResponse? {
        guard isInitialized else {
            throw SessionPersistenceError.coreDataNotInitialized
        }

        return try await withCheckedThrowingContinuation { continuation in
            let backgroundContext = newBackgroundContext()
            backgroundContext.perform {
                do {
                    let fetchRequest: NSFetchRequest<PersistedSession> = PersistedSession.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "sessionId == %@", sessionId)
                    fetchRequest.fetchLimit = 1

                    let results = try backgroundContext.fetch(fetchRequest)
                    guard let persistedSession = results.first else {
                        continuation.resume(returning: nil)
                        return
                    }

                    let session = try self.convertToSessionManagerResponse(persistedSession)
                    continuation.resume(returning: session)

                } catch {
                    continuation.resume(throwing: SessionPersistenceError.loadFailure(error))
                }
            }
        }
    }

    func loadRecentSessions(limit: Int) async throws -> [SessionManagerResponse] {
        guard isInitialized else {
            throw SessionPersistenceError.coreDataNotInitialized
        }

        return try await withCheckedThrowingContinuation { continuation in
            let backgroundContext = newBackgroundContext()
            backgroundContext.perform {
                do {
                    let fetchRequest: NSFetchRequest<PersistedSession> = PersistedSession.fetchRequest()
                    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "lastActiveAt", ascending: false)]
                    fetchRequest.fetchLimit = limit

                    let results = try backgroundContext.fetch(fetchRequest)
                    let sessions = try results.compactMap { try self.convertToSessionManagerResponse($0) }
                    continuation.resume(returning: sessions)

                } catch {
                    continuation.resume(throwing: SessionPersistenceError.loadFailure(error))
                }
            }
        }
    }

    func loadUserSessions(userId: String, limit: Int) async throws -> [SessionManagerResponse] {
        guard isInitialized else {
            throw SessionPersistenceError.coreDataNotInitialized
        }

        return try await withCheckedThrowingContinuation { continuation in
            let backgroundContext = newBackgroundContext()
            backgroundContext.perform {
                do {
                    let fetchRequest: NSFetchRequest<PersistedSession> = PersistedSession.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
                    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "lastActiveAt", ascending: false)]
                    fetchRequest.fetchLimit = limit

                    let results = try backgroundContext.fetch(fetchRequest)
                    let sessions = try results.compactMap { try self.convertToSessionManagerResponse($0) }
                    continuation.resume(returning: sessions)

                } catch {
                    continuation.resume(throwing: SessionPersistenceError.loadFailure(error))
                }
            }
        }
    }

    func deleteSession(sessionId: String) async throws {
        guard isInitialized else {
            throw SessionPersistenceError.coreDataNotInitialized
        }

        try await withCheckedThrowingContinuation { continuation in
            let backgroundContext = newBackgroundContext()
            backgroundContext.perform {
                do {
                    // Delete session
                    let sessionFetchRequest: NSFetchRequest<PersistedSession> = PersistedSession.fetchRequest()
                    sessionFetchRequest.predicate = NSPredicate(format: "sessionId == %@", sessionId)
                    let sessions = try backgroundContext.fetch(sessionFetchRequest)

                    // Delete related messages
                    let messageFetchRequest: NSFetchRequest<PersistedMessage> = PersistedMessage.fetchRequest()
                    messageFetchRequest.predicate = NSPredicate(format: "sessionId == %@", sessionId)
                    let messages = try backgroundContext.fetch(messageFetchRequest)

                    // Delete all entities
                    sessions.forEach { backgroundContext.delete($0) }
                    messages.forEach { backgroundContext.delete($0) }

                    try backgroundContext.save()
                    continuation.resume()

                } catch {
                    continuation.resume(throwing: SessionPersistenceError.saveFailure(error))
                }
            }
        }

        await updateStorageStatistics()
    }

    // MARK: - Message Management

    func saveConversationMessage(_ message: ConversationMessage) async throws {
        guard isInitialized else {
            throw SessionPersistenceError.coreDataNotInitialized
        }

        try await withCheckedThrowingContinuation { continuation in
            let backgroundContext = newBackgroundContext()
            backgroundContext.perform {
                do {
                    // Check if message already exists
                    let fetchRequest: NSFetchRequest<PersistedMessage> = PersistedMessage.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "messageId == %@", message.id)

                    let existingMessages = try backgroundContext.fetch(fetchRequest)
                    let persistedMessage = existingMessages.first ?? PersistedMessage(context: backgroundContext)

                    // Update message properties
                    persistedMessage.messageId = message.id
                    persistedMessage.sessionId = message.sessionId
                    persistedMessage.role = message.role.rawValue
                    persistedMessage.content = message.content
                    persistedMessage.timestamp = message.timestamp

                    // Serialize metadata
                    if let metadata = message.sessionManagerContext {
                        persistedMessage.metadata = try self.encoder.encode(metadata)
                    }

                    try backgroundContext.save()
                    continuation.resume()

                } catch {
                    continuation.resume(throwing: SessionPersistenceError.saveFailure(error))
                }
            }
        }
    }

    func loadConversationHistory(sessionId: String, limit: Int) async throws -> [ConversationMessage] {
        guard isInitialized else {
            throw SessionPersistenceError.coreDataNotInitialized
        }

        return try await withCheckedThrowingContinuation { continuation in
            let backgroundContext = newBackgroundContext()
            backgroundContext.perform {
                do {
                    let fetchRequest: NSFetchRequest<PersistedMessage> = PersistedMessage.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "sessionId == %@", sessionId)
                    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
                    fetchRequest.fetchLimit = limit

                    let results = try backgroundContext.fetch(fetchRequest)
                    let messages = try results.compactMap { try self.convertToConversationMessage($0) }
                    continuation.resume(returning: messages)

                } catch {
                    continuation.resume(throwing: SessionPersistenceError.loadFailure(error))
                }
            }
        }
    }

    // MARK: - Cleanup Operations

    func clearOldSessions(olderThan: Date) async throws {
        guard isInitialized else {
            throw SessionPersistenceError.coreDataNotInitialized
        }

        try await withCheckedThrowingContinuation { continuation in
            let backgroundContext = newBackgroundContext()
            backgroundContext.perform {
                do {
                    // Find old sessions
                    let sessionFetchRequest: NSFetchRequest<PersistedSession> = PersistedSession.fetchRequest()
                    sessionFetchRequest.predicate = NSPredicate(format: "lastActiveAt < %@", olderThan as NSDate)
                    let oldSessions = try backgroundContext.fetch(sessionFetchRequest)

                    // Find related messages
                    let sessionIds = oldSessions.map { $0.sessionId }
                    if !sessionIds.isEmpty {
                        let messageFetchRequest: NSFetchRequest<PersistedMessage> = PersistedMessage.fetchRequest()
                        messageFetchRequest.predicate = NSPredicate(format: "sessionId IN %@", sessionIds)
                        let relatedMessages = try backgroundContext.fetch(messageFetchRequest)

                        // Delete all entities
                        relatedMessages.forEach { backgroundContext.delete($0) }
                    }
                    oldSessions.forEach { backgroundContext.delete($0) }

                    try backgroundContext.save()
                    continuation.resume()

                    print("🧹 Cleaned up \(oldSessions.count) old sessions")

                } catch {
                    continuation.resume(throwing: SessionPersistenceError.saveFailure(error))
                }
            }
        }

        await updateStorageStatistics()
    }

    // MARK: - Storage Management

    func getStorageStatistics() async throws -> SessionStorageStats {
        guard isInitialized else {
            throw SessionPersistenceError.coreDataNotInitialized
        }

        return try await withCheckedThrowingContinuation { continuation in
            let backgroundContext = newBackgroundContext()
            backgroundContext.perform {
                do {
                    // Count sessions
                    let sessionFetchRequest: NSFetchRequest<PersistedSession> = PersistedSession.fetchRequest()
                    let totalSessions = try backgroundContext.count(for: sessionFetchRequest)

                    // Count messages
                    let messageFetchRequest: NSFetchRequest<PersistedMessage> = PersistedMessage.fetchRequest()
                    let totalMessages = try backgroundContext.count(for: messageFetchRequest)

                    // Get date range
                    let dateRangeFetchRequest: NSFetchRequest<PersistedSession> = PersistedSession.fetchRequest()
                    dateRangeFetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
                    dateRangeFetchRequest.fetchLimit = 1
                    let oldestSession = try backgroundContext.fetch(dateRangeFetchRequest).first

                    dateRangeFetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
                    let newestSession = try backgroundContext.fetch(dateRangeFetchRequest).first

                    // Estimate storage size (simplified calculation)
                    let estimatedStorageMB = Double(totalSessions * 10 + totalMessages * 5) / 1024.0 / 1024.0

                    let stats = SessionStorageStats(
                        totalSessions: totalSessions,
                        totalMessages: totalMessages,
                        storageUsedMB: estimatedStorageMB,
                        oldestSessionDate: oldestSession?.createdAt,
                        newestSessionDate: newestSession?.createdAt
                    )

                    continuation.resume(returning: stats)

                } catch {
                    continuation.resume(throwing: SessionPersistenceError.loadFailure(error))
                }
            }
        }
    }

    private func updateStorageStatistics() async {
        do {
            storageStats = try await getStorageStatistics()
        } catch {
            print("⚠️ Failed to update storage statistics: \(error)")
        }
    }

    // MARK: - Conversion Helpers

    private func convertToSessionManagerResponse(_ persistedSession: PersistedSession) throws -> SessionManagerResponse {
        // Deserialize conversation history
        var conversationHistory: [ConversationMessage]?
        if let conversationData = persistedSession.conversationData {
            conversationHistory = try decoder.decode([ConversationMessage].self, from: conversationData)
        }

        // Deserialize session manager stats
        var sessionManagerStats: SessionManagerStats?
        if let statsData = persistedSession.sessionManagerMetadata {
            sessionManagerStats = try decoder.decode(SessionManagerStats.self, from: statsData)
        }

        // Convert status
        guard let status = SessionStatus(rawValue: persistedSession.status) else {
            throw SessionPersistenceError.invalidSessionData
        }

        return SessionManagerResponse(
            sessionId: persistedSession.sessionId,
            userId: persistedSession.userId,
            sessionName: persistedSession.sessionName,
            workingDirectory: persistedSession.workingDirectory ?? "/default",
            status: status,
            createdAt: persistedSession.createdAt,
            lastActiveAt: persistedSession.lastActiveAt,
            messageCount: Int(persistedSession.messageCount),
            conversationHistory: conversationHistory,
            sessionManagerStats: sessionManagerStats
        )
    }

    private func convertToConversationMessage(_ persistedMessage: PersistedMessage) throws -> ConversationMessage {
        // Convert role
        guard let role = MessageRole(rawValue: persistedMessage.role) else {
            throw SessionPersistenceError.invalidSessionData
        }

        // Deserialize metadata
        var sessionManagerContext: [String: AnyCodable]?
        if let metadataData = persistedMessage.metadata {
            sessionManagerContext = try decoder.decode([String: AnyCodable].self, from: metadataData)
        }

        return ConversationMessage(
            id: persistedMessage.messageId,
            role: role,
            content: persistedMessage.content,
            timestamp: persistedMessage.timestamp,
            sessionId: persistedMessage.sessionId,
            messageId: persistedMessage.messageId,
            sessionManagerContext: sessionManagerContext
        )
    }

    // MARK: - Background Operations

    /// Perform background persistence for app lifecycle transitions
    func performBackgroundPersistence() async {
        guard let container = persistentContainer else {
            print("⚠️ Background persistence failed: container not initialized")
            return
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            container.performBackgroundTask { context in
                do {
                    if context.hasChanges {
                        try context.save()
                        print("✅ Background persistence completed")
                    }
                } catch {
                    print("⚠️ Background persistence failed: \(error)")
                }
                continuation.resume()
            }
        }
    }

    /// Perform emergency persistence during app termination
    func performEmergencyPersistence() async {
        guard let container = persistentContainer else {
            print("🚨 Emergency persistence failed: container not initialized")
            return
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            container.performBackgroundTask { context in
                do {
                    if context.hasChanges {
                        try context.save()
                        print("🚨 Emergency persistence completed")
                    }
                } catch {
                    print("🚨 Emergency persistence failed: \(error)")
                }
                continuation.resume()
            }
        }
    }
}

// MARK: - CoreData Model Extensions
// NOTE: fetchRequest methods are defined above with the model definitions