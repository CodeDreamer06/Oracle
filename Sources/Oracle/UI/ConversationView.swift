import SwiftUI

struct ConversationView: View {
    let messages: [ConversationMessage]
    let toolStatus: [String: ToolExecutionStatus]
    
    var body: some View {
        ScrollView {
            ScrollViewReader { proxy in
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(visibleMessages) { message in
                        MessageBubble(message: message, toolStatus: toolStatus)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .onChange(of: messages.count) { _, _ in
                    if let last = visibleMessages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }
    
    // Hide raw tool result messages from the UI since results are shown inline in ToolCallView
    private var visibleMessages: [ConversationMessage] {
        messages.filter { $0.role != .tool }
    }
}

struct MessageBubble: View {
    let message: ConversationMessage
    let toolStatus: [String: ToolExecutionStatus]
    
    @ViewBuilder
    private var contentView: some View {
        if message.role == .assistant {
            if let attributed = try? AttributedString(
                markdown: message.content,
                options: AttributedString.MarkdownParsingOptions(
                    interpretedSyntax: .inlineOnlyPreservingWhitespace
                )
            ), !message.content.isEmpty {
                Text(attributed)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineSpacing(2)
            } else if !message.content.isEmpty {
                Text(message.content)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineSpacing(2)
            }
        } else {
            Text(message.content)
                .font(.system(size: message.role == .user ? 15 : 16))
                .fontWeight(message.role == .user ? .regular : .medium)
                .foregroundStyle(.primary)
                .lineSpacing(2)
        }
    }
    
    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            
            VStack(alignment: .leading, spacing: 8) {
                if let toolCalls = message.toolCalls, !toolCalls.isEmpty {
                    ForEach(toolCalls, id: \.id) { tc in
                        ToolCallView(
                            toolCall: tc,
                            status: toolStatus[tc.id]
                        )
                    }
                }
                
                contentView
                
                if message.isStreaming {
                    HStack(spacing: 4) {
                        Circle()
                            .frame(width: 4, height: 4)
                        Circle()
                            .frame(width: 4, height: 4)
                        Circle()
                            .frame(width: 4, height: 4)
                    }
                    .foregroundStyle(.secondary.opacity(0.5))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(message.role == .user
                          ? Color.accentColor.opacity(0.12)
                          : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(message.role == .user
                            ? Color.accentColor.opacity(0.15)
                            : Color.white.opacity(0.06), lineWidth: 0.5)
            )
            
            if message.role == .assistant || message.role == .tool { Spacer(minLength: 40) }
        }
    }
}
