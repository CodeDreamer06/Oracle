import Foundation

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, body: String)
    case decodingFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL."
        case .invalidResponse:
            return "Invalid server response."
        case .httpError(let statusCode, let body):
            return "HTTP \(statusCode): \(body)"
        case .decodingFailed(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}

struct NetworkClient {
    static let shared = NetworkClient()
    private let session: URLSession
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }
    
    func postJSON<T: Decodable>(
        url: URL,
        headers: [String: String],
        body: [String: Any]
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let bodyString = String(data: data, encoding: .utf8) ?? ""
            throw NetworkError.httpError(statusCode: httpResponse.statusCode, body: bodyString)
        }
        
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingFailed(error)
        }
    }
    
    func streamSSE(
        url: URL,
        headers: [String: String],
        body: [String: Any]
    ) async throws -> AsyncThrowingStream<SSEEvent, Error> {
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let capturedHeaders = headers
        let capturedSession = session
        
        let (stream, continuation) = AsyncThrowingStream<SSEEvent, Error>.makeStream()
        
        Task {
            do {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                for (key, value) in capturedHeaders {
                    request.setValue(value, forHTTPHeaderField: key)
                }
                request.httpBody = bodyData
                
                let (bytes, response) = try await capturedSession.bytes(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    var bodyData = Data()
                    for try await byte in bytes {
                        bodyData.append(byte)
                    }
                    let bodyString = String(data: bodyData, encoding: .utf8) ?? ""
                    throw NetworkError.httpError(statusCode: httpResponse.statusCode, body: bodyString)
                }
                
                for try await line in bytes.lines {
                    if line.hasPrefix("data: ") {
                        let dataContent = String(line.dropFirst(6))
                        if dataContent == "[DONE]" {
                            continuation.finish()
                            return
                        }
                        if let event = SSEEvent.parse(dataContent) {
                            continuation.yield(event)
                        }
                    }
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        
        return stream
    }
    
    func fetchURL(_ url: URL) async throws -> String {
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.invalidResponse
        }
        return String(data: data, encoding: .utf8) ?? ""
    }
}

struct SSEEvent {
    let id: String?
    let data: String
    
    static func parse(_ jsonString: String) -> SSEEvent? {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return SSEEvent(id: json["id"] as? String, data: jsonString)
    }
}
