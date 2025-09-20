//
//  ClaudeStreamingServiceProtocol.swift
//  Protocol defining streaming operations
//

import Foundation

@MainActor
protocol ClaudeStreamingServiceProtocol: AnyObject {
    func streamQuery(_ request: ClaudeQueryRequest) -> AsyncThrowingStream<StreamingChunk, Error>
    func streamQueryWithSessionManager(_ request: ClaudeQueryRequest) -> AsyncThrowingStream<StreamingChunk, Error>
}