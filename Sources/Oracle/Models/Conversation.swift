import Foundation

struct ConversationMessage: Identifiable, Equatable {
    let id: UUID
    var role: MessageRole
    var content: String
    var toolCalls: [ToolCall]?
    var isStreaming: Bool
    
    enum MessageRole: String, Codable, Equatable {
        case user, assistant, tool
    }
    
    init(id: UUID = UUID(), role: MessageRole, content: String, toolCalls: [ToolCall]? = nil, isStreaming: Bool = false) {
        self.id = id
        self.role = role
        self.content = content
        self.toolCalls = toolCalls
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
