import Foundation

struct Provider: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var baseURL: String
    var apiKeyIdentifier: String
    
    var apiKey: String {
        (try? KeychainHelper.read(key: apiKeyIdentifier)) ?? ""
    }
    
    init(id: UUID = UUID(), name: String, baseURL: String, apiKeyIdentifier: String? = nil) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.apiKeyIdentifier = apiKeyIdentifier ?? id.uuidString
    }
    
    static var `default`: Provider {
        Provider(name: "OpenAI", baseURL: "https://api.openai.com/v1")
    }
}
