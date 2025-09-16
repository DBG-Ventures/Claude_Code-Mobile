//
//  ClaudeMessage.swift
//  Core data models for Claude Code mobile client.
//
//  Swift data models matching the FastAPI backend Pydantic schema exactly.
//  Provides type-safe communication between iOS client and FastAPI backend.
//

import Foundation

// MARK: - Enumerations

/// Message role enumeration matching backend MessageRole
enum MessageRole: String, CaseIterable, Codable {
    case user = "user"
    case assistant = "assistant"
    case system = "system"
}

/// Session status enumeration matching backend SessionStatus
enum SessionStatus: String, CaseIterable, Codable {
    case active = "active"
    case completed = "completed"
    case error = "error"
    case paused = "paused"
}

/// Streaming chunk type for real-time responses
enum StreamingChunkType: String, Codable {
    case start = "start"
    case delta = "delta"
    case complete = "complete"
    case error = "error"
    case assistant = "assistant"
    case thinking = "thinking"
    case tool = "tool"
    case system = "system"
}

// MARK: - Core Data Models

/// Individual Claude message within a conversation
/// Matches backend ClaudeMessage Pydantic model exactly
struct ClaudeMessage: Identifiable, Codable, Hashable {
    let id: String
    let content: String
    let role: MessageRole
    let timestamp: Date
    let sessionId: String
    let metadata: [String: AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case id
        case content
        case role
        case timestamp
        case sessionId = "session_id"
        case metadata
    }

    init(id: String, content: String, role: MessageRole, timestamp: Date, sessionId: String, metadata: [String: AnyCodable]? = nil) {
        self.id = id
        self.content = content
        self.role = role
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.metadata = metadata
    }
}

/// Individual chunk in a streaming response
/// Matches backend StreamingChunk Pydantic model exactly
struct StreamingChunk: Identifiable, Codable {
    var id: String { messageId ?? UUID().uuidString }
    let content: String?
    let chunkType: StreamingChunkType
    let messageId: String?
    let timestamp: Date

    // Error fields for handling backend errors
    let error: String?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case content
        case chunkType = "chunk_type"
        case messageId = "message_id"
        case timestamp
        case error
        case message
    }

    init(content: String? = nil, chunkType: StreamingChunkType = .delta, messageId: String? = nil, timestamp: Date = Date(), error: String? = nil, message: String? = nil) {
        self.content = content
        self.chunkType = chunkType
        self.messageId = messageId
        self.timestamp = timestamp
        self.error = error
        self.message = message
    }
}

/// Claude Code SDK options configuration
/// Matches backend ClaudeCodeOptions Pydantic model exactly
struct ClaudeCodeOptions: Codable {
    let apiKey: String?
    let model: String?
    let maxTokens: Int
    let temperature: Double
    let timeout: Int

    enum CodingKeys: String, CodingKey {
        case apiKey = "api_key"
        case model
        case maxTokens = "max_tokens"
        case temperature
        case timeout
    }

    init(apiKey: String? = nil,
         model: String? = nil, // Use default (latest) model when nil
         maxTokens: Int = 8192,
         temperature: Double = 0.7,
         timeout: Int = 60) {
        self.apiKey = apiKey
        self.model = model
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.timeout = timeout
    }
}

// MARK: - Request Models

/// Request to create a new Claude Code session
/// Matches backend SessionRequest Pydantic model exactly
struct SessionRequest: Codable {
    let userId: String
    let claudeOptions: ClaudeCodeOptions
    let sessionName: String?
    let workingDirectory: String?
    let context: [String: AnyCodable]

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case claudeOptions = "claude_options"
        case sessionName = "session_name"
        case workingDirectory = "working_directory"
        case context
    }

    init(userId: String, claudeOptions: ClaudeCodeOptions, sessionName: String? = nil, workingDirectory: String? = nil, context: [String: AnyCodable] = [:]) {
        self.userId = userId
        self.claudeOptions = claudeOptions
        self.sessionName = sessionName
        self.workingDirectory = workingDirectory
        self.context = context
    }
}

/// Request to send a query to Claude within a session
/// Matches backend ClaudeQueryRequest Pydantic model exactly
struct ClaudeQueryRequest: Codable {
    let sessionId: String
    let query: String
    let userId: String
    let stream: Bool
    let options: ClaudeCodeOptions?
    let context: [String: AnyCodable]

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case query
        case userId = "user_id"
        case stream
        case options
        case context
    }

    init(sessionId: String, query: String, userId: String, stream: Bool = true, options: ClaudeCodeOptions? = nil, context: [String: AnyCodable] = [:]) {
        self.sessionId = sessionId
        self.query = query
        self.userId = userId
        self.stream = stream
        self.options = options
        self.context = context
    }
}

// MARK: - Response Models

/// Response containing session information
/// Matches backend SessionResponse Pydantic model exactly
struct SessionResponse: Identifiable, Codable {
    let sessionId: String
    let userId: String
    let sessionName: String?
    let status: SessionStatus
    let messages: [ClaudeMessage]
    let createdAt: Date
    let updatedAt: Date
    let messageCount: Int
    let context: [String: AnyCodable]

    var id: String { sessionId }

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case userId = "user_id"
        case sessionName = "session_name"
        case status
        case messages
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case messageCount = "message_count"
        case context
    }
}

/// Response to a Claude query request
/// Matches backend ClaudeQueryResponse Pydantic model exactly
struct ClaudeQueryResponse: Codable {
    let sessionId: String
    let message: ClaudeMessage
    let status: String
    let processingTime: Double?

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case message
        case status
        case processingTime = "processing_time"
    }
}

/// Standardized error response
/// Matches backend ErrorResponse Pydantic model exactly
struct ErrorResponse: Codable, Error {
    let error: String
    let message: String
    let details: [String: AnyCodable]?
    let timestamp: Date
    let requestId: String?

    enum CodingKeys: String, CodingKey {
        case error
        case message
        case details
        case timestamp
        case requestId = "request_id"
    }
}

// MARK: - Helper Types

/// Type-erased wrapper for any codable value
/// Enables flexible JSON handling for metadata and context fields
enum AnyCodable: Codable, Hashable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null
    case array([AnyCodable])
    case object([String: AnyCodable])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([AnyCodable].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: AnyCodable].self) {
            self = .object(object)
        } else {
            throw DecodingError.typeMismatch(AnyCodable.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported type"))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let string):
            try container.encode(string)
        case .int(let int):
            try container.encode(int)
        case .double(let double):
            try container.encode(double)
        case .bool(let bool):
            try container.encode(bool)
        case .null:
            try container.encodeNil()
        case .array(let array):
            try container.encode(array)
        case .object(let object):
            try container.encode(object)
        }
    }
}

// MARK: - AnyCodable Extensions

extension AnyCodable {
    var string: String? {
        if case .string(let value) = self {
            return value
        }
        return nil
    }
    
    var int: Int? {
        if case .int(let value) = self {
            return value
        }
        return nil
    }
    
    var double: Double? {
        if case .double(let value) = self {
            return value
        }
        return nil
    }
    
    var bool: Bool? {
        if case .bool(let value) = self {
            return value
        }
        return nil
    }
}