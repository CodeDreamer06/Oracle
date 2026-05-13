import Foundation

enum STTMode: String, Codable, CaseIterable, Identifiable {
    case api
    case macOSDefault

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .api: return "API Provider"
        case .macOSDefault: return "macOS Default"
        }
    }
}

@Observable
@MainActor
final class AppSettings {
    var providers: [Provider] = []
    var models: [AIModel] = []
    var selectedVoice: String = "M2"
    var selectedModelId: UUID?
    var sttMode: STTMode = .api
    var sttProviderId: UUID?
    var sttModel: String = "gpt-4o-transcribe"
    var inactivityTimeout: Double = 30.0
    var totalStep: Int = 8
    var speechSpeed: Float = 1.05

    private let providersKey = "oracle.providers"
    private let modelsKey = "oracle.models"
    private let voiceKey = "oracle.selectedVoice"
    private let modelIdKey = "oracle.selectedModelId"
    private let sttModeKey = "oracle.sttMode"
    private let sttProviderKey = "oracle.sttProviderId"
    private let sttModelKey = "oracle.sttModel"
    private let timeoutKey = "oracle.inactivityTimeout"
    private let totalStepKey = "oracle.totalStep"
    private let speedKey = "oracle.speechSpeed"

    init() {
        load()
        if providers.isEmpty {
            let openai = Provider.default
            providers = [openai]
            models = [
                AIModel(providerId: openai.id, modelId: "gpt-4o", displayName: "GPT-4o", isDefault: true)
            ]
            selectedModelId = models.first?.id
            sttProviderId = openai.id
        }
    }

    func load() {
        if let data = UserDefaults.standard.data(forKey: providersKey),
           let decoded = try? JSONDecoder().decode([Provider].self, from: data) {
            providers = decoded
        }
        if let data = UserDefaults.standard.data(forKey: modelsKey),
           let decoded = try? JSONDecoder().decode([AIModel].self, from: data) {
            models = decoded
        }
        selectedVoice = UserDefaults.standard.string(forKey: voiceKey) ?? "M2"
        if let idString = UserDefaults.standard.string(forKey: modelIdKey),
           let id = UUID(uuidString: idString) {
            selectedModelId = id
        }
        if let rawMode = UserDefaults.standard.string(forKey: sttModeKey),
           let mode = STTMode(rawValue: rawMode) {
            sttMode = mode
        }
        if let idString = UserDefaults.standard.string(forKey: sttProviderKey),
           let id = UUID(uuidString: idString) {
            sttProviderId = id
        }
        sttModel = UserDefaults.standard.string(forKey: sttModelKey) ?? "gpt-4o-transcribe"
        inactivityTimeout = UserDefaults.standard.double(forKey: timeoutKey)
        if inactivityTimeout == 0 { inactivityTimeout = 30.0 }
        totalStep = UserDefaults.standard.integer(forKey: totalStepKey)
        if totalStep == 0 { totalStep = 8 }
        speechSpeed = UserDefaults.standard.object(forKey: speedKey) as? Float ?? 1.05
    }

    func save() {
        if let data = try? JSONEncoder().encode(providers) {
            UserDefaults.standard.set(data, forKey: providersKey)
        }
        if let data = try? JSONEncoder().encode(models) {
            UserDefaults.standard.set(data, forKey: modelsKey)
        }
        UserDefaults.standard.set(selectedVoice, forKey: voiceKey)
        UserDefaults.standard.set(selectedModelId?.uuidString, forKey: modelIdKey)
        UserDefaults.standard.set(sttMode.rawValue, forKey: sttModeKey)
        UserDefaults.standard.set(sttProviderId?.uuidString, forKey: sttProviderKey)
        UserDefaults.standard.set(sttModel, forKey: sttModelKey)
        UserDefaults.standard.set(inactivityTimeout, forKey: timeoutKey)
        UserDefaults.standard.set(totalStep, forKey: totalStepKey)
        UserDefaults.standard.set(speechSpeed, forKey: speedKey)
    }

    var selectedModel: AIModel? {
        models.first { $0.id == selectedModelId }
    }

    var selectedProvider: Provider? {
        guard let model = selectedModel else { return nil }
        return providers.first { $0.id == model.providerId }
    }

    var sttProvider: Provider? {
        providers.first { $0.id == sttProviderId }
    }
}
