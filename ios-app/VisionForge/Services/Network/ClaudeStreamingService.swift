//
//  ClaudeStreamingService.swift
//  Server-Sent Events streaming service for Claude API communication
//
//  Handles SSE stream parsing, chunk processing, and reconnection logic.
//  Extracted from ClaudeService.swift to follow single responsibility principle.
//

import Foundation
import Observation

// Protocol imported from Services/Protocols/ClaudeStreamingServiceProtocol.swift

/// Service responsible for handling streaming operations with Claude API
/// Manages Server-Sent Events, chunk processing, retry logic, and connection monitoring
@MainActor
@Observable
final class ClaudeStreamingService: ClaudeStreamingServiceProtocol {

    // MARK: - Observable Properties

    var isStreaming: Bool = false
    var lastStreamError: Error?

    // MARK: - Private Properties

    private let networkClient: NetworkClientProtocol
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    // Retry configuration
    private let maxRetryAttempts = 3
    private let baseRetryDelay: TimeInterval = 1.0
    private let maxRetryDelay: TimeInterval = 30.0

    // MARK: - Initialization

    init(networkClient: NetworkClientProtocol) {
        self.networkClient = networkClient

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

    // MARK: - ClaudeStreamingServiceProtocol Implementation

    /// Streams a query to Claude API with standard retry logic
    func streamQuery(_ request: ClaudeQueryRequest) -> AsyncThrowingStream<StreamingChunk, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                await streamQueryWithRetry(request: request, continuation: continuation, attempt: 0)
            }
        }
    }

    /// Streams a query to Claude API with SessionManager-specific handling
    func streamQueryWithSessionManager(_ request: ClaudeQueryRequest) -> AsyncThrowingStream<StreamingChunk, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                await streamQueryWithSessionManagerRetry(request: request, continuation: continuation, attempt: 0)
            }
        }
    }

    // MARK: - Private Implementation

    /// Standard streaming with retry logic
    private func streamQueryWithRetry(
        request: ClaudeQueryRequest,
        continuation: AsyncThrowingStream<StreamingChunk, Error>.Continuation,
        attempt: Int
    ) async {
        do {
            isStreaming = true
            lastStreamError = nil

            let requestData = try encoder.encode(request)
            let streamData = networkClient.stream("claude/stream", method: .post, body: requestData)

            var hasReceivedData = false

            // Process Server-Sent Events with connection monitoring
            for try await data in streamData {
                let line = String(data: data, encoding: .utf8) ?? ""

                if line.hasPrefix("data: ") {
                    hasReceivedData = true
                    await processStreamingLine(line, continuation: continuation)
                }
            }

            // If stream ended without completion, check if retry is needed
            if !hasReceivedData && attempt < maxRetryAttempts {
                let delay = calculateRetryDelay(attempt: attempt, statusCode: 0)
                print("⚠️ Stream ended without data, retrying in \(delay)s (attempt \(attempt + 1)/\(maxRetryAttempts))")

                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                await streamQueryWithRetry(request: request, continuation: continuation, attempt: attempt + 1)
            } else {
                continuation.finish()
            }

        } catch {
            // Handle network errors with retry
            if attempt < maxRetryAttempts && isRetryableError(error) {
                let delay = calculateRetryDelay(attempt: attempt, statusCode: 0)
                print("⚠️ Stream error: \(error.localizedDescription), retrying in \(delay)s (attempt \(attempt + 1)/\(maxRetryAttempts))")

                do {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    await streamQueryWithRetry(request: request, continuation: continuation, attempt: attempt + 1)
                } catch {
                    lastStreamError = error
                    continuation.finish(throwing: error)
                }
            } else {
                lastStreamError = error
                continuation.finish(throwing: error)
            }
        }

        isStreaming = false
    }

    /// SessionManager-specific streaming with enhanced error handling
    private func streamQueryWithSessionManagerRetry(
        request: ClaudeQueryRequest,
        continuation: AsyncThrowingStream<StreamingChunk, Error>.Continuation,
        attempt: Int
    ) async {
        do {
            isStreaming = true
            lastStreamError = nil

            let requestData = try encoder.encode(request)
            let streamData = networkClient.stream("claude/stream", method: .post, body: requestData)

            var hasReceivedData = false

            // Process Server-Sent Events with SessionManager context preservation
            for try await data in streamData {
                let line = String(data: data, encoding: .utf8) ?? ""

                if line.hasPrefix("data: ") {
                    hasReceivedData = true
                    await processStreamingLine(line, continuation: continuation)
                }
            }

            // If stream ended without completion, check if retry is needed
            if !hasReceivedData && attempt < maxRetryAttempts {
                let delay = calculateRetryDelay(attempt: attempt, statusCode: 0)
                print("⚠️ SessionManager stream ended without data, retrying in \(delay)s (attempt \(attempt + 1)/\(maxRetryAttempts))")

                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                await streamQueryWithSessionManagerRetry(request: request, continuation: continuation, attempt: attempt + 1)
            } else {
                continuation.finish()
            }

        } catch {
            // Handle network errors with retry
            if attempt < maxRetryAttempts && isRetryableError(error) {
                let delay = calculateRetryDelay(attempt: attempt, statusCode: 0)
                print("⚠️ SessionManager stream error: \(error.localizedDescription), retrying in \(delay)s (attempt \(attempt + 1)/\(maxRetryAttempts))")

                do {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    await streamQueryWithSessionManagerRetry(request: request, continuation: continuation, attempt: attempt + 1)
                } catch {
                    lastStreamError = error
                    continuation.finish(throwing: error)
                }
            } else {
                lastStreamError = error
                continuation.finish(throwing: error)
            }
        }

        isStreaming = false
    }

    /// Process individual streaming lines and decode chunks
    private func processStreamingLine(
        _ line: String,
        continuation: AsyncThrowingStream<StreamingChunk, Error>.Continuation
    ) async {
        let jsonData = String(line.dropFirst(6)) // Remove "data: " prefix

        guard let data = jsonData.data(using: .utf8) else {
            print("⚠️ Failed to convert streaming line to data: \(jsonData)")
            return
        }

        do {
            let chunk = try decoder.decode(StreamingChunk.self, from: data)
            continuation.yield(chunk)

            // Check for completion or error chunks
            if chunk.chunkType == .complete || chunk.chunkType == .error {
                continuation.finish()
                return
            }
        } catch {
            print("⚠️ Failed to decode streaming chunk: \(error)")
            print("⚠️ Raw data: \(jsonData)")
            // Continue processing other chunks instead of failing the entire stream
        }
    }

    /// Calculate exponential backoff delay with jitter
    private func calculateRetryDelay(attempt: Int, statusCode: Int) -> TimeInterval {
        let exponentialDelay = min(baseRetryDelay * pow(2.0, Double(attempt)), maxRetryDelay)
        let jitter = Double.random(in: 0...0.3) * exponentialDelay

        // Additional delay for rate limiting
        if statusCode == 429 {
            return exponentialDelay + jitter + 5.0
        }

        return exponentialDelay + jitter
    }

    /// Determine if an error is retryable
    private func isRetryableError(_ error: Error) -> Bool {
        // Check for retryable network errors
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .networkConnectionLost, .notConnectedToInternet,
                 .dnsLookupFailed, .cannotConnectToHost:
                return true
            default:
                return false
            }
        }

        // Check for our custom errors
        if let serviceError = error as? ClaudeServiceError {
            switch serviceError {
            case .connectionTimeout, .healthCheckFailed:
                return true
            default:
                return false
            }
        }

        return false
    }
}