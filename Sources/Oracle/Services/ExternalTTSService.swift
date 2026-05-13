import Foundation
import os.log

private let logger = Logger(subsystem: "com.abhinav.oracle", category: "ExternalTTS")

enum ExternalTTSError: Error, LocalizedError {
    case noProvider
    case noText
    case requestFailed(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .noProvider:
            return "No TTS provider configured. Please add a provider in Settings."
        case .noText:
            return "No text provided for speech synthesis."
        case .requestFailed(let msg):
            return "TTS API error: \(msg)"
        case .invalidResponse:
            return "Invalid response from TTS API."
        }
    }
}

struct TTSSpeechRequest: Encodable {
    let model: String
    let input: String
    let voice: String
    let responseFormat: String = "mp3"
    let speed: Float
}

struct ExternalTTSService {
    static func synthesize(
        text: String,
        provider: Provider?,
        model: String,
        voice: String,
        speed: Float
    ) async throws -> Data {
        guard let provider = provider else {
            throw ExternalTTSError.noProvider
        }

        guard !text.isEmpty else {
            throw ExternalTTSError.noText
        }

        let url = URL(string: "\(provider.baseURL)/audio/speech")!
        let requestBody = TTSSpeechRequest(
            model: model,
            input: text,
            voice: voice,
            speed: speed
        )

        let bodyData = try JSONEncoder().encode(requestBody)
        let apiKey = provider.apiKey

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData

        logger.info("Starting API TTS synthesis with model \(model), voice \(voice)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ExternalTTSError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ExternalTTSError.requestFailed("HTTP \(httpResponse.statusCode): \(body)")
        }

        logger.info("API TTS synthesis completed successfully, received \(data.count) bytes")
        return data
    }
}
