import Foundation

struct AIModel: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var providerId: UUID
    var modelId: String
    var displayName: String
    var isDefault: Bool
    
    init(id: UUID = UUID(), providerId: UUID, modelId: String, displayName: String? = nil, isDefault: Bool = false) {
        self.id = id
        self.providerId = providerId
        self.modelId = modelId
        self.displayName = displayName ?? modelId
        self.isDefault = isDefault
    }
}
