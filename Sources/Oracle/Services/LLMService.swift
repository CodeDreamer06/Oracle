import Foundation

struct LLMMessage: Codable {
    let role: String
    let content: String?
    var toolCalls: [LLMToolCall]? = nil
    var toolCallId: String? = nil
    
    enum CodingKeys: String, CodingKey {
        case role, content
        case toolCalls = "tool_calls"
        case toolCallId = "tool_call_id"
    }
}

struct LLMToolCall: Codable {
    let id: String
    let type: String
    let function: LLMToolFunction
}

struct LLMToolFunction: Codable {
    let name: String
    let arguments: String
}

struct LLMRequestBody: Codable {
    let model: String
    let messages: [LLMMessage]
    let tools: [ToolDefinition]?
    let stream: Bool
}

struct LLMDelta: Equatable {
    let content: String?
    let toolCalls: [ToolCallDelta]?
}

struct ToolCallDelta: Equatable {
    let index: Int
    let id: String
    let name: String
    let arguments: String
}

enum LLMError: Error, LocalizedError {
    case noProvider
    case invalidURL
    case streamFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noProvider:
            return "No LLM provider configured."
        case .invalidURL:
            return "Invalid provider base URL."
        case .streamFailed(let msg):
            return "LLM stream failed: \(msg)"
        }
    }
}

struct LLMService {
    func streamChat(
        messages: [LLMMessage],
        provider: Provider,
        model: AIModel,
        tools: [ToolDefinition]
    ) async throws -> AsyncThrowingStream<LLMDelta, Error> {
        guard let url = URL(string: "\(provider.baseURL)/chat/completions") else {
            throw LLMError.invalidURL
        }
        
        let systemMessage = LLMMessage(
            role: "system",
            content: "You are Oracle, a helpful voice-activated macOS assistant. You have access to tools that let you search the web, run shell commands, execute AppleScript, and read files. Be concise but helpful in your responses since they will be spoken aloud. When you need to use a tool, do so confidently. Always explain what you're doing before using a tool."
        )
        
        var allMessages = [systemMessage]
        allMessages.append(contentsOf: messages)
        
        let body: [String: Any] = [
            "model": model.modelId,
            "messages": allMessages.map { msg in
                var dict: [String: Any] = [
                    "role": msg.role
                ]
                // OpenAI requires content to be present (can be null for assistant with tool_calls)
                if let content = msg.content {
                    dict["content"] = content
                } else {
                    dict["content"] = NSNull()
                }
                if let toolCalls = msg.toolCalls {
                    dict["tool_calls"] = toolCalls.map { tc in
                        [
                            "id": tc.id,
                            "type": tc.type,
                            "function": [
                                "name": tc.function.name,
                                "arguments": tc.function.arguments
                            ]
                        ]
                    }
                }
                if let toolCallId = msg.toolCallId {
                    dict["tool_call_id"] = toolCallId
                }
                return dict
            },
            "tools": tools.map { tool in
                [
                    "type": tool.type,
                    "function": [
                        "name": tool.function.name,
                        "description": tool.function.description,
                        "parameters": [
                            "type": tool.function.parameters.type,
                            "properties": tool.function.parameters.properties.reduce(into: [String: [String: String]]()) { result, pair in
                                result[pair.key] = [
                                    "type": pair.value.type,
                                    "description": pair.value.description
                                ]
                            },
                            "required": tool.function.parameters.required
                        ]
                    ]
                ]
            },
            "stream": true
        ]
        
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let apiKey = provider.apiKey
        
        let (stream, continuation) = AsyncThrowingStream<LLMDelta, Error>.makeStream()
        
        Task {
            do {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                request.httpBody = bodyData
                
                let (bytes, response) = try await URLSession.shared.bytes(for: request)
                
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
                
                // Track accumulated tool call state by index
                var currentToolCalls: [Int: ToolCallDelta] = [:]
                
                for try await line in bytes.lines {
                    guard line.hasPrefix("data: ") else { continue }
                    let dataContent = String(line.dropFirst(6))
                    
                    if dataContent == "[DONE]" {
                        break
                    }
                    
                    guard let data = dataContent.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let choices = json["choices"] as? [[String: Any]],
                          let firstChoice = choices.first,
                          let delta = firstChoice["delta"] as? [String: Any] else {
                        continue
                    }
                    
                    var content: String?
                    var toolCallDeltas: [ToolCallDelta]?
                    
                    if let text = delta["content"] as? String {
                        content = text
                    }
                    
                    if let tcs = delta["tool_calls"] as? [[String: Any]] {
                        var deltas: [ToolCallDelta] = []
                        for tc in tcs {
                            guard let index = tc["index"] as? Int else { continue }
                            
                            var current = currentToolCalls[index] ?? ToolCallDelta(index: index, id: "", name: "", arguments: "")
                            var didChange = false
                            
                            if let id = tc["id"] as? String, !id.isEmpty, current.id != id {
                                current = ToolCallDelta(index: index, id: id, name: current.name, arguments: current.arguments)
                                didChange = true
                            }
                            
                            if let function = tc["function"] as? [String: Any] {
                                if let name = function["name"] as? String, !name.isEmpty, current.name != name {
                                    current = ToolCallDelta(index: index, id: current.id, name: name, arguments: current.arguments)
                                    didChange = true
                                }
                                if let args = function["arguments"] as? String, !args.isEmpty {
                                    current = ToolCallDelta(index: index, id: current.id, name: current.name, arguments: current.arguments + args)
                                    didChange = true
                                }
                            }
                            
                            currentToolCalls[index] = current
                            // Only yield if there was actual new data for this chunk
                            if didChange {
                                deltas.append(current)
                            }
                        }
                        if !deltas.isEmpty {
                            toolCallDeltas = deltas
                        }
                    }
                    
                    if content != nil || toolCallDeltas != nil {
                        continuation.yield(LLMDelta(content: content, toolCalls: toolCallDeltas))
                    }
                    
                    if let finishReason = firstChoice["finish_reason"] as? String, finishReason == "stop" || finishReason == "tool_calls" {
                        break
                    }
                }
                
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        
        return stream
    }
}
