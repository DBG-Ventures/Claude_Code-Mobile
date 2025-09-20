//
//  SessionCacheManager.swift
//  LRU cache implementation for session management
//
//  Extracted from SessionRepository for clean separation of cache concerns.
//  Implements efficient LRU eviction with size limits and access tracking.
//

import Foundation
import Observation

// MARK: - Protocol Definition

protocol SessionCacheManagerProtocol {
    func cacheSession(_ session: SessionManagerResponse) async
    func getCachedSession(_ sessionId: String) async -> SessionManagerResponse?
    func evictOldestCachedSessions() async
    func updateCacheSize() async
    func getCacheSize() async -> Int
    func clearCache() async
}

/// LRU cache manager for session data with size limits and eviction
@MainActor
@Observable
final class SessionCacheManager: CacheProtocol, SessionCacheManagerProtocol {

    // MARK: - Type Aliases

    typealias Key = String
    typealias Value = SessionManagerResponse

    // MARK: - Observable Properties

    private(set) var count: Int = 0
    private(set) var cacheHits: Int = 0
    private(set) var cacheMisses: Int = 0
    private(set) var evictionCount: Int = 0
    private(set) var lastEvictionDate: Date?

    // MARK: - Configuration

    let maxSize: Int
    private let maxConversationHistoryPerSession: Int

    // MARK: - Storage

    private var storage: [String: SessionManagerResponse] = [:]
    private var accessOrder: [String] = []
    private var conversationCache: [String: [ConversationMessage]] = [:]

    // MARK: - Initialization

    init(maxSize: Int = 20, maxConversationHistoryPerSession: Int = 100) {
        self.maxSize = maxSize
        self.maxConversationHistoryPerSession = maxConversationHistoryPerSession
    }

    // MARK: - CacheProtocol Implementation

    func get(_ key: String) async -> SessionManagerResponse? {
        if let value = storage[key] {
            updateAccessOrder(for: key)
            cacheHits += 1
            return value
        } else {
            cacheMisses += 1
            return nil
        }
    }

    func set(_ key: String, value: SessionManagerResponse) async {
        storage[key] = value
        updateAccessOrder(for: key)

        // Update conversation cache if needed
        if let history = value.conversationHistory {
            await setConversationHistory(for: key, history: history)
        }

        // Check if eviction is needed
        if storage.count > maxSize {
            await evictLeastRecentlyUsed()
        }

        await updateCount()
    }

    func evict(_ key: String) async {
        storage.removeValue(forKey: key)
        conversationCache.removeValue(forKey: key)
        accessOrder.removeAll { $0 == key }
        evictionCount += 1
        await updateCount()
    }

    func clear() async {
        storage.removeAll()
        conversationCache.removeAll()
        accessOrder.removeAll()
        evictionCount += storage.count
        await updateCount()
    }

    func setMultiple(_ items: [(key: String, value: SessionManagerResponse)]) async {
        for item in items {
            await set(item.key, value: item.value)
        }
    }

    func evictMultiple(_ keys: [String]) async {
        for key in keys {
            await evict(key)
        }
    }

    func contains(_ key: String) async -> Bool {
        return storage.keys.contains(key)
    }

    func getCacheStatistics() async -> CacheStatistics {
        let memoryUsage = calculateMemoryUsage()

        return CacheStatistics(
            totalEntries: storage.count,
            cacheHits: cacheHits,
            cacheMisses: cacheMisses,
            evictionCount: evictionCount,
            lastEvictionDate: lastEvictionDate,
            memoryUsageMB: memoryUsage
        )
    }

    // MARK: - SessionCacheManagerProtocol Implementation

    func cacheSession(_ session: SessionManagerResponse) async {
        await set(session.sessionId, value: session)
    }

    func getCachedSession(_ sessionId: String) async -> SessionManagerResponse? {
        return await get(sessionId)
    }

    func evictOldestCachedSessions() async {
        await evictLeastRecentlyUsed()
    }

    func updateCacheSize() async {
        await updateCount()
    }

    func getCacheSize() async -> Int {
        return storage.count
    }

    func clearCache() async {
        await clear()
    }

    // MARK: - Conversation History Management

    func getConversationHistory(for sessionId: String) async -> [ConversationMessage]? {
        return conversationCache[sessionId]
    }

    func setConversationHistory(for sessionId: String, history: [ConversationMessage]) async {
        let trimmedHistory = Array(history.suffix(maxConversationHistoryPerSession))
        conversationCache[sessionId] = trimmedHistory
    }

    func addConversationMessage(_ message: ConversationMessage) async {
        var history = conversationCache[message.sessionId] ?? []
        history.append(message)

        // Trim if too long
        if history.count > maxConversationHistoryPerSession {
            history = Array(history.suffix(maxConversationHistoryPerSession))
        }

        conversationCache[message.sessionId] = history
    }

    // MARK: - LRU Implementation

    private func updateAccessOrder(for key: String) {
        // Remove existing entry
        accessOrder.removeAll { $0 == key }
        // Add to end (most recently used)
        accessOrder.append(key)
    }

    private func evictLeastRecentlyUsed() async {
        let targetSize = maxSize - 5 // Evict a few extra to reduce frequency
        let keysToEvict = accessOrder.prefix(storage.count - targetSize)

        for key in keysToEvict {
            storage.removeValue(forKey: key)
            conversationCache.removeValue(forKey: key)
        }

        // Update access order
        accessOrder.removeAll { key in keysToEvict.contains(key) }

        evictionCount += keysToEvict.count
        lastEvictionDate = Date()

        print("🧹 Evicted \(keysToEvict.count) sessions from cache (LRU)")
    }

    private func updateCount() async {
        count = storage.count
    }

    // MARK: - Memory Management

    private func calculateMemoryUsage() -> Double {
        // Rough estimation of memory usage in MB
        let sessionSize = storage.values.reduce(0) { total, session in
            let baseSize = 1024 // Base session object
            let historySize = (session.conversationHistory?.count ?? 0) * 512 // Rough message size
            return total + baseSize + historySize
        }

        let conversationSize = conversationCache.values.reduce(0) { total, messages in
            return total + (messages.count * 512)
        }

        return Double(sessionSize + conversationSize) / (1024 * 1024) // Convert to MB
    }

    // MARK: - Cache Optimization

    func performMaintenance() async {
        // Remove sessions that are too old
        let oneWeekAgo = Date().addingTimeInterval(-7 * 24 * 3600)
        let expiredKeys = storage.compactMap { key, session in
            session.lastActiveAt < oneWeekAgo ? key : nil
        }

        await evictMultiple(expiredKeys)

        // Trim conversation histories
        for (sessionId, history) in conversationCache {
            if history.count > maxConversationHistoryPerSession {
                let trimmed = Array(history.suffix(maxConversationHistoryPerSession))
                conversationCache[sessionId] = trimmed
            }
        }

        print("🔧 Cache maintenance completed: removed \(expiredKeys.count) expired sessions")
    }

    // MARK: - Debug Helpers

    func getDebugInfo() -> String {
        return """
        SessionCacheManager Debug:
        - Total entries: \(storage.count)/\(maxSize)
        - Cache hits: \(cacheHits)
        - Cache misses: \(cacheMisses)
        - Evictions: \(evictionCount)
        - Memory usage: \(String(format: "%.2f", calculateMemoryUsage()))MB
        - Conversation cache entries: \(conversationCache.count)
        """
    }
}