import SwiftUI

struct ToolConfirmationView: View {
    let request: ToolConfirmationRequest
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.orange)
                
                Text("Confirm Action")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.primary)
                
                Spacer()
            }
            
            Text("Oracle wants to execute a potentially destructive command:")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            
            HStack(spacing: 8) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.cyan)
                Text(request.toolCall.name)
                    .font(.system(size: 13, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Spacer()
            }
            
            ScrollView {
                Text(formattedArguments)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .frame(maxHeight: 120)
            .background(Color.black.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
            )
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    request.onCancel()
                }
                .buttonStyle(GlassButtonStyle(tint: .secondary))
                .keyboardShortcut(.cancelAction)
                
                Button("Execute") {
                    request.onConfirm()
                }
                .buttonStyle(GlassButtonStyle(tint: .orange, isProminent: true))
            }
        }
        .padding(18)
        .background(
            VisualEffectBlur(material: .hudWindow)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.orange.opacity(0.3),
                            Color.white.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        )
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.orange.opacity(0.05),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
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

struct GlassButtonStyle: ButtonStyle {
    var tint: Color
    var isProminent: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(isProminent ? .white : .primary)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isProminent
                          ? tint.opacity(configuration.isPressed ? 0.7 : 0.9)
                          : Color.white.opacity(configuration.isPressed ? 0.08 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isProminent
                            ? tint.opacity(0.4)
                            : Color.white.opacity(0.08), lineWidth: 0.5)
            )
    }
}
