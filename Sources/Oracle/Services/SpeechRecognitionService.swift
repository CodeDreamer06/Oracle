import Foundation

enum SpeechRecognitionError: Error, LocalizedError {
    case noProvider
    case fileReadFailed
    case uploadFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noProvider:
            return "No STT provider configured. Please add a provider in Settings."
        case .fileReadFailed:
            return "Failed to read recorded audio file."
        case .uploadFailed(let msg):
            return "Transcription API error: \(msg)"
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
}
