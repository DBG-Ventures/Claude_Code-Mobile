//
//  NetworkClientProtocol.swift
//  Protocol defining network operations abstraction
//

import Foundation

@MainActor
protocol NetworkClientProtocol: AnyObject {

    var isConnected: Bool { get }
    var baseURL: URL { get }

    // Core request methods
    func request<T: Decodable>(_ endpoint: String, method: HTTPMethod, body: Data?) async throws -> T

    // Stream operations for SSE
    func stream(_ endpoint: String, method: HTTPMethod, body: Data?) -> AsyncThrowingStream<Data, Error>

    // Convenience methods
    func get<T: Decodable>(_ endpoint: String) async throws -> T
    func post<T: Decodable, U: Encodable>(_ endpoint: String, body: U) async throws -> T
    func put<T: Decodable, U: Encodable>(_ endpoint: String, body: U) async throws -> T
    func delete(_ endpoint: String) async throws

    // Health and connection management
    func checkHealth() async throws -> Bool
    func connect() async throws
    func disconnect() async
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}