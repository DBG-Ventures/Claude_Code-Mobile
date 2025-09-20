//
//  ClaudeQueryServiceProtocol.swift
//  Protocol defining query operations
//

import Foundation

@MainActor
protocol ClaudeQueryServiceProtocol: AnyObject {
    func sendQuery(_ request: ClaudeQueryRequest) async throws -> ClaudeQueryResponse
}