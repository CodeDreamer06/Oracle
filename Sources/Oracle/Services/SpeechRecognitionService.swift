import Foundation
@preconcurrency import Speech
import os.log

private let logger = Logger(subsystem: "com.abhinav.oracle", category: "SpeechRecognition")

enum SpeechRecognitionError: Error, LocalizedError {
    case noProvider
    case fileReadFailed
    case uploadFailed(String)
    case macOSRecognitionNotAvailable
    case macOSRecognitionDenied
    case macOSRecognitionFailed(String)

    var errorDescription: String? {
        switch self {
        case .noProvider:
            return "No STT provider configured. Please add a provider in Settings."
        case .fileReadFailed:
            return "Failed to read recorded audio file."
        case .uploadFailed(let msg):
            return "Transcription API error: \(msg)"
        case .macOSRecognitionNotAvailable:
            return "macOS speech recognition is not available on this device."
        case .macOSRecognitionDenied:
            return "Speech recognition permission was denied. Please enable it in System Settings > Privacy & Security > Speech Recognition."
        case .macOSRecognitionFailed(let msg):
            return "macOS speech recognition failed: \(msg)"
        }
    }
}

struct TranscriptionResponse: Decodable {
    let text: String
}

struct SpeechRecognitionService {
    static func transcribe(
        audioURL: URL,
        provider: Provider?,
        model: String
    ) async throws -> String {
        guard let provider = provider else {
            throw SpeechRecognitionError.noProvider
        }

        guard let audioData = try? Data(contentsOf: audioURL) else {
            throw SpeechRecognitionError.fileReadFailed
        }

        let url = URL(string: "\(provider.baseURL)/audio/transcriptions")!
        var builder = MultipartBuilder()
        builder.addFile(name: "file", filename: "audio.m4a", mimeType: "audio/m4a", data: audioData)
        builder.addField(name: "model", value: model)
        builder.addField(name: "language", value: "en")

        let bodyData = builder.build()
        let contentType = builder.contentType
        let apiKey = provider.apiKey

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpeechRecognitionError.uploadFailed("Invalid response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw SpeechRecognitionError.uploadFailed("HTTP \(httpResponse.statusCode): \(body)")
        }

        let result = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
        return result.text
    }

    static func transcribeWithMacOSStream(audioURL: URL) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    if SFSpeechRecognizer.authorizationStatus() != .authorized {
                        let status = await withCheckedContinuation { cont in
                            SFSpeechRecognizer.requestAuthorization { status in
                                cont.resume(returning: status)
                            }
                        }
                        guard status == .authorized else {
                            throw SpeechRecognitionError.macOSRecognitionDenied
                        }
                    }

                    guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")) else {
                        throw SpeechRecognitionError.macOSRecognitionNotAvailable
                    }

                    guard recognizer.isAvailable else {
                        throw SpeechRecognitionError.macOSRecognitionNotAvailable
                    }

                    let request = SFSpeechURLRecognitionRequest(url: audioURL)
                    request.shouldReportPartialResults = true
                    request.requiresOnDeviceRecognition = false

                    let recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                        if let error = error {
                            continuation.finish(throwing: SpeechRecognitionError.macOSRecognitionFailed(error.localizedDescription))
                            return
                        }

                        guard let result = result else {
                            continuation.finish(throwing: SpeechRecognitionError.macOSRecognitionFailed("No result"))
                            return
                        }

                        continuation.yield(result.bestTranscription.formattedString)

                        if result.isFinal {
                            let text = result.bestTranscription.formattedString
                            logger.info("macOS STT final result: \(text)")
                            continuation.finish()
                        }
                    }

                    continuation.onTermination = { _ in
                        recognitionTask.cancel()
                    }

                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    static func transcribeWithMacOS(audioURL: URL) async throws -> String {
        let stream = transcribeWithMacOSStream(audioURL: audioURL)
        var finalText = ""
        for try await text in stream {
            finalText = text
        }
        return finalText
    }
}
