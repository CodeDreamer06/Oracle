import SwiftUI

struct ToolCallView: View {
    let toolCall: ToolCall
    let status: ToolExecutionStatus?
    
    @State private var isExpanded = false
    
    private var toolInfo: (icon: String, color: Color, displayName: String) {
        switch toolCall.name {
        case "execute_shell":
            return ("terminal.fill", .cyan, "Terminal")
        case "run_applescript":
            return ("applescript.fill", .pink, "AppleScript")
        case "web_search":
            return ("magnifyingglass", .purple, "Web Search")
        case "fetch_url":
            return ("arrow.down.circle.fill", .indigo, "Fetch URL")
        case "list_directory":
            return ("folder.fill", .blue, "List Directory")
        case "read_file":
            return ("doc.text.fill", .orange, "Read File")
        default:
            return ("hammer.fill", .teal, toolCall.name)
        }
    }
    
    private var formattedArguments: String {
        guard let data = toolCall.arguments.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) else {
            return toolCall.arguments
        }
        return String(data: prettyData, encoding: .utf8) ?? toolCall.arguments
    }
    
    private var argumentsPreview: String {
        let full = formattedArguments
        let lines = full.components(separatedBy: .newlines)
        if lines.count > 3 {
            return lines.prefix(3).joined(separator: "\n") + "\n..."
        }
        return full
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(toolInfo.color.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: toolInfo.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(toolInfo.color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(toolInfo.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                    
                    StatusLabel(status: status)
                }
                
                Spacer()
                
                Button(action: { withAnimation(.spring(duration: 0.3)) { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary.opacity(0.7))
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            
            // Arguments
            VStack(alignment: .leading, spacing: 0) {
                Divider()
                    .background(Color.white.opacity(0.06))
                
                if isExpanded {
                    Text(formattedArguments)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary.opacity(0.85))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(argumentsPreview)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary.opacity(0.7))
                        .lineLimit(3)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .background(Color.black.opacity(0.15))
            
            // Result
            if let status = status {
                switch status {
                case .completed(let result), .failed(let result):
                    VStack(alignment: .leading, spacing: 0) {
                        Divider()
                            .background(Color.white.opacity(0.06))
                        
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: status == .completed(result) ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(status == .completed(result) ? .green : .red)
                                .padding(.top, 2)
                            
                            Text(result)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary.opacity(0.85))
                                .lineLimit(isExpanded ? nil : 4)
                        }
                        .padding(12)
                    }
                    .background(
                        status == .completed(result)
                            ? Color.green.opacity(0.04)
                            : Color.red.opacity(0.04)
                    )
                case .pending, .running:
                    EmptyView()
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            toolInfo.color.opacity(0.25),
                            Color.white.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        )
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            toolInfo.color.opacity(0.03),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
    }
}

struct StatusLabel: View {
    let status: ToolExecutionStatus?
    
    @State private var isPulsing = false
    
    var body: some View {
        HStack(spacing: 5) {
            switch status {
            case .pending:
                Circle()
                    .frame(width: 6, height: 6)
                    .foregroundStyle(.orange)
                    .opacity(isPulsing ? 0.4 : 1.0)
                Text("Waiting for confirmation...")
                    .foregroundStyle(.orange.opacity(0.8))
                
            case .running:
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.7)
                    .frame(width: 12, height: 12)
                Text("Executing...")
                    .foregroundStyle(.cyan.opacity(0.8))
                
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.green)
                Text("Done")
                    .foregroundStyle(.green.opacity(0.8))
                
            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
                Text("Failed")
                    .foregroundStyle(.red.opacity(0.8))
                
            case .none:
                Image(systemName: "circle.dotted")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary.opacity(0.5))
                Text("Ready")
                    .foregroundStyle(.secondary.opacity(0.6))
            }
        }
        .font(.system(size: 11, weight: .medium))
        .onAppear {
            if case .pending = status {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
        }
    }
}
