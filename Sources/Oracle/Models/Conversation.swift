import Foundation

struct ConversationMessage: Identifiable, Equatable {
    let id: UUID
    var role: MessageRole
    var content: String
    var toolCalls: [ToolCall]?
    var toolCallId: String?
    var isStreaming: Bool
    
    enum MessageRole: String, Codable, Equatable {
        case user, assistant, tool
    }
    
    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        toolCalls: [ToolCall]? = nil,
        toolCallId: String? = nil,
        isStreaming: Bool = false
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.toolCalls = toolCalls
        self.toolCallId = toolCallId
        self.isStreaming = isStreaming
    }
}

struct ToolCall: Equatable {
    let id: String
    let name: String
    let arguments: String
}

struct ToolResult {
    let toolCallId: String
    let content: String
}

enum ToolExecutionStatus: Equatable {
    case pending
    case running
    case completed(String)
    case failed(String)
}
