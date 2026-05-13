import Foundation
import AVFoundation
import os.log

private let logger = Logger(subsystem: "com.abhinav.oracle", category: "AppState")

@Observable
@MainActor
final class AppState {
    var assistantState: AssistantState = .idle
    var messages: [ConversationMessage] = []
    var isPanelVisible = false
    var currentError: OracleError?
    var pendingToolConfirmation: ToolConfirmationRequest?
    
    let settings = AppSettings()
    private let audioRecorder = AudioRecorder()
    private let audioPlayer = AudioPlayerService()
    private let tts = SupertonicTTS()
    private let llm = LLMService()
    private let toolExecutor = ToolExecutor()
    private var inactivityTimer: Timer?
    private var listeningVolumeTimer: Timer?
    private var silenceTimer: Timer?
    private var lastSoundTime: Date = Date()
    
    // MARK: - Panel Control
    
    func togglePanel() {
        if isPanelVisible {
            dismissPanel()
        } else {
            showPanel()
        }
    }
    
    func showPanel() {
        isPanelVisible = true
        resetInactivityTimer()
    }
    
    func dismissPanel() {
        isPanelVisible = false
        cancelInactivityTimer()
        stopListening()
        audioPlayer.stop()
        messages.removeAll()
        assistantState = .idle
    }
    
    func resetInactivityTimer() {
        cancelInactivityTimer()
        guard settings.inactivityTimeout > 0 else { return }
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: settings.inactivityTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.dismissPanel()
            }
        }
    }
    
    private func cancelInactivityTimer() {
        inactivityTimer?.invalidate()
        inactivityTimer = nil
    }
    
    func userActivityOccurred() {
        resetInactivityTimer()
    }
    
    // MARK: - Listening
    
    func startListening() async {
        guard isPanelVisible else {
            logger.warning("startListening called but panel is not visible")
            return
        }
        userActivityOccurred()
        
        do {
            logger.info("Starting listening...")
            assistantState = .listening(volume: 0)
            try await audioRecorder.startRecording()
            
            // Poll volume for waveform visualization and silence detection
            lastSoundTime = Date()
            listeningVolumeTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard case .listening = self?.assistantState else { return }
                    let volume = self?.audioRecorder.currentDecibelLevel ?? 0
                    self?.assistantState = .listening(volume: volume)
                    
                    if volume > 0.08 {
                        self?.lastSoundTime = Date()
                    }
                }
            }
            
            // Auto-stop after 4 seconds of silence
            silenceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard case .listening = self?.assistantState else { return }
                    guard let self = self else { return }
                    let silenceDuration = Date().timeIntervalSince(self.lastSoundTime)
                    if silenceDuration > 2.0 {
                        self.silenceTimer?.invalidate()
                        self.silenceTimer = nil
                        await self.finishListening()
                    }
                }
            }
        } catch {
            logger.error("Failed to start listening: \(error.localizedDescription)")
            showError(title: "Microphone Error", message: error.localizedDescription)
            assistantState = .idle
        }
    }
    
    func stopListening() {
        logger.info("Stopping listening")
        listeningVolumeTimer?.invalidate()
        listeningVolumeTimer = nil
        silenceTimer?.invalidate()
        silenceTimer = nil
        audioRecorder.stopRecording()
    }
    
    func finishListening() async {
        logger.info("Finishing listening, beginning transcription")
        stopListening()
        assistantState = .transcribing
        userActivityOccurred()
        
        guard let audioURL = audioRecorder.recordedFileURL else {
            logger.error("No audio file was created")
            showError(title: "Recording Error", message: "No audio file was created.")
            assistantState = .idle
            return
        }
        
        do {
            let text: String
            switch settings.sttMode {
            case .macOSDefault:
                text = try await SpeechRecognitionService.transcribeWithMacOS(audioURL: audioURL)
            case .api:
                text = try await SpeechRecognitionService.transcribe(
                    audioURL: audioURL,
                    provider: settings.sttProvider,
                    model: settings.sttModel
                )
            }

            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                logger.info("Transcription was empty")
                assistantState = .idle
                return
            }

            logger.info("Transcription received: \(text)")
            await processUserMessage(text)
        } catch {
            logger.error("Transcription failed: \(error.localizedDescription)")
            showError(title: "Transcription Failed", message: error.localizedDescription)
            assistantState = .idle
        }
    }
    
    // MARK: - Message Processing
    
    func processUserMessage(_ text: String) async {
        userActivityOccurred()
        let userMessage = ConversationMessage(role: .user, content: text)
        messages.append(userMessage)
        
        await streamLLMResponse()
    }
    
    func streamLLMResponse() async {
        guard let provider = settings.selectedProvider,
              let model = settings.selectedModel else {
            showError(title: "No Model Selected", message: "Please configure an LLM provider and model in Settings.")
            assistantState = .idle
            return
        }
        
        assistantState = .thinking
        userActivityOccurred()
        logger.info("Starting LLM stream with model \(model.modelId)")
        
        // Convert messages to LLM format
        let history = messages.map { msg -> LLMMessage in
            LLMMessage(role: msg.role.rawValue, content: msg.content)
        }
        
        let assistantMessage = ConversationMessage(role: .assistant, content: "", isStreaming: true)
        messages.append(assistantMessage)
        
        do {
            let stream = try await llm.streamChat(
                messages: history,
                provider: provider,
                model: model,
                tools: ToolDefinition.allTools
            )
            
            var collectedContent = ""
            var collectedToolCalls: [ToolCall] = []
            
            for try await delta in stream {
                userActivityOccurred()
                
                if let content = delta.content {
                    collectedContent += content
                    if let lastIndex = messages.indices.last {
                        messages[lastIndex].content = collectedContent
                        messages[lastIndex].isStreaming = true
                    }
                }
                
                if let toolCalls = delta.toolCalls {
                    for tc in toolCalls {
                        if let existing = collectedToolCalls.firstIndex(where: { $0.id == tc.id }) {
                            collectedToolCalls[existing] = ToolCall(
                                id: tc.id,
                                name: collectedToolCalls[existing].name,
                                arguments: collectedToolCalls[existing].arguments + tc.arguments
                            )
                        } else {
                            collectedToolCalls.append(ToolCall(id: tc.id, name: tc.name, arguments: tc.arguments))
                        }
                    }
                }
            }
            
            if let lastIndex = messages.indices.last {
                messages[lastIndex].isStreaming = false
            }
            
            // Handle tool calls
            if !collectedToolCalls.isEmpty {
                logger.info("LLM requested \(collectedToolCalls.count) tool call(s)")
                if let lastIndex = messages.indices.last {
                    messages[lastIndex].toolCalls = collectedToolCalls
                }
                await executeToolCalls(collectedToolCalls)
                return
            }
            
            // Speak the response
            if !collectedContent.isEmpty {
                logger.info("LLM response complete, speaking: \(collectedContent.prefix(100))...")
                await speak(collectedContent)
            } else {
                logger.info("LLM response was empty")
                assistantState = .idle
            }
            
        } catch {
            logger.error("LLM stream failed: \(error.localizedDescription)")
            showError(title: "LLM Error", message: error.localizedDescription)
            if let lastIndex = messages.indices.last, messages[lastIndex].role == .assistant {
                messages[lastIndex].isStreaming = false
            }
            assistantState = .idle
        }
    }
    
    // MARK: - Tool Execution
    
    func executeToolCalls(_ toolCalls: [ToolCall]) async {
        guard !toolCalls.isEmpty else { return }
        
        for toolCall in toolCalls {
            userActivityOccurred()
            
            // Check if confirmation is needed
            if toolExecutor.requiresConfirmation(toolCall: toolCall) {
                pendingToolConfirmation = ToolConfirmationRequest(
                    toolCall: toolCall,
                    onConfirm: { [weak self] in
                        Task { @MainActor in
                            self?.pendingToolConfirmation = nil
                            await self?.executeSingleTool(toolCall)
                        }
                    },
                    onCancel: { [weak self] in
                        Task { @MainActor in
                            self?.pendingToolConfirmation = nil
                            let result = ToolResult(toolCallId: toolCall.id, content: "User cancelled the tool execution.")
                            self?.addToolResult(result)
                        }
                    }
                )
                assistantState = .toolExecuting(name: toolCall.name)
                return // Wait for user confirmation
            }
            
            await executeSingleTool(toolCall)
        }
    }
    
    func executeSingleTool(_ toolCall: ToolCall) async {
        assistantState = .toolExecuting(name: toolCall.name)
        userActivityOccurred()
        
        do {
            let result = try await toolExecutor.execute(toolCall: toolCall)
            addToolResult(result)
        } catch {
            let result = ToolResult(
                toolCallId: toolCall.id,
                content: "Error executing tool: \(error.localizedDescription)"
            )
            addToolResult(result)
        }
    }
    
    func addToolResult(_ result: ToolResult) {
        let toolMessage = ConversationMessage(
            role: .tool,
            content: result.content
        )
        messages.append(toolMessage)
        
        // Continue the conversation with the tool result
        Task {
            await streamLLMResponse()
        }
    }
    
    // MARK: - TTS
    
    func speak(_ text: String) async {
        assistantState = .speaking
        userActivityOccurred()
        logger.info("Starting speech synthesis")
        
        do {
            let audioData = try await tts.synthesize(
                text: text,
                voiceStyle: settings.selectedVoice,
                lang: "en",
                totalStep: settings.totalStep,
                speed: settings.speechSpeed
            )
            try await audioPlayer.play(data: audioData)
            assistantState = .idle
            resetInactivityTimer()
            
            // Auto-start listening for multi-turn conversations
            if isPanelVisible && !messages.isEmpty {
                try? await Task.sleep(nanoseconds: 300_000_000)
                await startListening()
            }
        } catch {
            logger.error("Speech synthesis failed: \(error.localizedDescription)")
            showError(title: "Speech Synthesis Error", message: error.localizedDescription)
            assistantState = .idle
        }
    }
    
    func stopSpeaking() {
        audioPlayer.stop()
        assistantState = .idle
    }
    
    func demoVoice() async {
        let demoText = "Hello! This is how I sound."
        logger.info("Playing voice demo")
        
        do {
            let audioData = try await tts.synthesize(
                text: demoText,
                voiceStyle: settings.selectedVoice,
                lang: "en",
                totalStep: settings.totalStep,
                speed: settings.speechSpeed
            )
            try await audioPlayer.play(data: audioData)
        } catch {
            logger.error("Voice demo failed: \(error.localizedDescription)")
            showError(title: "Voice Demo Error", message: error.localizedDescription)
        }
    }
    
    // MARK: - Errors
    
    func showError(title: String, message: String) {
        currentError = OracleError(title: title, message: message)
    }
    
    func dismissError() {
        currentError = nil
    }
}

struct ToolConfirmationRequest: Identifiable {
    let id = UUID()
    let toolCall: ToolCall
    let onConfirm: () -> Void
    let onCancel: () -> Void
}
