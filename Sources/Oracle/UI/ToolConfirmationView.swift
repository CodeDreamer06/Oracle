import SwiftUI

struct ToolConfirmationView: View {
    let request: ToolConfirmationRequest
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Confirm Action")
                    .font(.headline)
                Spacer()
            }
            
            Text("Oracle wants to execute a potentially destructive command:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text(request.toolCall.name)
                .font(.system(.subheadline, design: .monospaced))
                .fontWeight(.semibold)
            
            ScrollView {
                Text(formattedArguments)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 100)
            .padding(8)
            .background(Color.black.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    request.onCancel()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
                
                Button("Execute") {
                    request.onConfirm()
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.orange.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private var formattedArguments: String {
        guard let data = request.toolCall.arguments.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) else {
            return request.toolCall.arguments
        }
        return String(data: prettyData, encoding: .utf8) ?? request.toolCall.arguments
    }
}
