import SwiftUI

struct ConversationView: View {
    let messages: [ConversationMessage]
    
    var body: some View {
        ScrollView {
            ScrollViewReader { proxy in
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }
}

struct MessageBubble: View {
    let message: ConversationMessage
    
    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            
            VStack(alignment: .leading, spacing: 4) {
                if let toolCalls = message.toolCalls {
                    ForEach(toolCalls, id: \.id) { tc in
                        HStack(spacing: 4) {
                            Image(systemName: "hammer.fill")
                                .font(.caption2)
                            Text("Using \(tc.name)...")
                                .font(.caption)
                        }
                        .foregroundStyle(.orange)
                    }
                }
                
                Text(message.content)
                    .font(.system(size: message.role == .user ? 15 : 16))
                    .fontWeight(message.role == .user ? .regular : .medium)
                    .foregroundStyle(message.role == .user ? .primary : .primary)
                    .lineSpacing(2)
                
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
