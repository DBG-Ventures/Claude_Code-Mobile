//
//  CacheProtocol.swift
//  Generic cache protocol with associated type
//

import Foundation

@MainActor
protocol CacheProtocol: AnyObject {
    associatedtype Key: Hashable
    associatedtype Value

    // Core cache operations
    func get(_ key: Key) async -> Value?
    func set(_ key: Key, value: Value) async
    func evict(_ key: Key) async
    func clear() async

    // Bulk operations
    func setMultiple(_ items: [(key: Key, value: Value)]) async
    func evictMultiple(_ keys: [Key]) async

    // Cache management
    var count: Int { get async }
    var maxSize: Int { get }
    func contains(_ key: Key) async -> Bool

    // Statistics
    func getCacheStatistics() async -> CacheStatistics
}

struct CacheStatistics {
    let totalEntries: Int
    let cacheHits: Int
    let cacheMisses: Int
    let evictionCount: Int
    let lastEvictionDate: Date?
    let memoryUsageMB: Double
}