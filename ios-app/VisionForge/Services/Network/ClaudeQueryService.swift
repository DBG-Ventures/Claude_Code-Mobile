//
//  ClaudeQueryService.swift
//  Query operations service for Claude API communication
//
//  Handles both standard and streaming query operations.
//  Depends on ClaudeStreamingService for streaming functionality.
//

import Foundation
import Observation

// Protocol imported from Services/Protocols/ClaudeQueryServiceProtocol.swift

/// Service responsible for handling query operations with Claude API
/// Manages both standard synchronous queries and streaming operations
@MainActor
@Observable
final class ClaudeQueryService: ClaudeQueryServiceProtocol {

    // MARK: - Observable Properties

    var isProcessingQuery: Bool = false
    var lastQueryError: Error?

    // MARK: - Private Properties

    private let networkClient: NetworkClientProtocol
    private let streamingService: ClaudeStreamingServiceProtocol
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    // MARK: - Initialization

    init(networkClient: NetworkClientProtocol, streamingService: ClaudeStreamingServiceProtocol) {
        self.networkClient = networkClient
        self.streamingService = streamingService

        // Configure JSON coders with date formatting
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        encoder.dateEncodingStrategy = .formatted(dateFormatter)
        decoder.dateDecodingStrategy = .formatted(dateFormatter)
    }

    // MARK: - ClaudeQueryServiceProtocol Implementation

    /// Send a synchronous query to Claude API
    func sendQuery(_ request: ClaudeQueryRequest) async throws -> ClaudeQueryResponse {
        guard networkClient.isConnected else {
            throw ClaudeServiceError.healthCheckFailed
        }

        isProcessingQuery = true
        lastQueryError = nil

        do {
            let response: ClaudeQueryResponse = try await networkClient.post("claude/query", body: request)
            isProcessingQuery = false
            return response
        } catch {
            lastQueryError = error
            isProcessingQuery = false
            throw error
        }
    }

    /// Stream a query to Claude API using the streaming service
    func streamQuery(_ request: ClaudeQueryRequest) -> AsyncThrowingStream<StreamingChunk, Error> {
        guard networkClient.isConnected else {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: ClaudeServiceError.healthCheckFailed)
            }
        }

        return streamingService.streamQuery(request)
    }

    /// Stream a query to Claude API with SessionManager integration
    func streamQueryWithSessionManager(_ request: ClaudeQueryRequest) -> AsyncThrowingStream<StreamingChunk, Error> {
        guard networkClient.isConnected else {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: ClaudeServiceError.sessionManagerUnavailable)
            }
        }

        return streamingService.streamQueryWithSessionManager(request)
    }
}