import SwiftUI

struct AssistantPanel: View {
    @Environment(AppState.self) private var appState
    
    var statusText: String {
        switch appState.assistantState {
        case .idle:
            return appState.messages.isEmpty ? "Tap the orb or speak" : "Listening..."
        case .listening:
            return "Listening..."
        case .transcribing:
            return "Transcribing..."
        case .thinking:
            return "Thinking..."
        case .speaking:
            return "Speaking..."
        case .toolExecuting(let name):
            return "Executing \(name)..."
        }
    }
    
    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow)
            
            VStack(spacing: 0) {
                // Error banner
                if let error = appState.currentError {
                    ErrorBanner(error: error) {
                        appState.dismissError()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Messages
                if !appState.messages.isEmpty {
                    ConversationView(messages: appState.messages)
                        .frame(maxHeight: 280)
                }
                
                Spacer(minLength: 20)
                
                // Tool confirmation
                if let confirmation = appState.pendingToolConfirmation {
                    ToolConfirmationView(request: confirmation)
                        .padding(.horizontal, 16)
                        .transition(.scale.combined(with: .opacity))
                }
                
                Spacer(minLength: 20)
                
                // Orb
                OrbView(state: appState.assistantState)
                    .frame(width: 140, height: 140)
                    .onTapGesture {
                        Task {
                            switch appState.assistantState {
                            case .idle:
                                await appState.startListening()
                            case .listening:
                                await appState.finishListening()
                            case .speaking:
                                appState.stopSpeaking()
                            default:
                                break
                            }
                        }
                    }
                
                // Status text
                Text(statusText)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
            }
        }
        .frame(width: 520, height: 520)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 60, x: 0, y: 30)
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 0.8)
        )
    }
}

struct ErrorBanner: View {
    let error: OracleError
    let dismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(error.title)
                    .font(.system(size: 13, weight: .semibold))
                Text(error.message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.red.opacity(0.08))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color.red.opacity(0.15)),
            alignment: .bottom
        )
    }
}
