import SwiftUI
import AppKit
import KeyboardShortcuts

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var showingAddProvider = false
    @State private var showingAddModel = false
    @State private var editingProvider: Provider?
    @State private var editingModel: AIModel?
    
    private let voices = [
        ("M1", "M1 — Lively, upbeat"),
        ("M2", "M2 — Deep, robust (Default)"),
        ("M3", "M3 — Polished, authoritative"),
        ("M4", "M4 — Soft, neutral"),
        ("M5", "M5 — Warm, soft-spoken"),
        ("F1", "F1 — Calm, steady"),
        ("F2", "F2 — Bright, cheerful"),
        ("F3", "F3 — Clear, professional"),
        ("F4", "F4 — Crisp, confident"),
        ("F5", "F5 — Kind, gentle")
    ]
    
    var body: some View {
        @Bindable var settings = appState.settings
        
        Form {
            Section {
                HStack {
                    Text("Voice")
                    Spacer()
                    Picker("", selection: $settings.selectedVoice) {
                        ForEach(voices, id: \.0) { voice in
                            Text(voice.1).tag(voice.0)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(maxWidth: 250)
                    
                    Button {
                        Task { await appState.demoVoice() }
                    } label: {
                        Image(systemName: "play.fill")
                    }
                    .buttonStyle(.borderless)
                }
                
                Picker("Quality Steps", selection: $settings.totalStep) {
                    Text("Fast (4)").tag(4)
                    Text("Balanced (8)").tag(8)
                    Text("High (10)").tag(10)
                    Text("Ultra (15)").tag(15)
                }
                .pickerStyle(.menu)
                
                HStack {
                    Text("Speed")
                    Slider(value: $settings.speechSpeed, in: 0.8...2.5, step: 0.05)
                    Text(String(format: "%.2fx", settings.speechSpeed))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 40)
                }
                
                HStack {
                    Text("Timeout")
                    Slider(value: $settings.inactivityTimeout, in: 10...120, step: 5)
                    Text("\(Int(settings.inactivityTimeout))s")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 40)
                }
            } header: {
                Text("Voice & Behavior")
            }
            
            Section {
                ForEach(settings.providers) { provider in
                    ProviderRow(provider: provider) {
                        editingProvider = provider
                    }
                }
                .onDelete { indexSet in
                    settings.providers.remove(atOffsets: indexSet)
                    settings.save()
                }
                
                Button("Add Provider") {
                    showingAddProvider = true
                }
            } header: {
                Text("LLM Providers")
            }
            
            Section {
                ForEach(settings.models) { model in
                    ModelRow(model: model, providerName: providerName(for: model.providerId)) {
                        editingModel = model
                    }
                }
                .onDelete { indexSet in
                    settings.models.remove(atOffsets: indexSet)
                    settings.save()
                }
                
                Button("Add Model") {
                    showingAddModel = true
                }
            } header: {
                Text("Models")
            }
            
            Section {
                Picker("STT Mode", selection: $settings.sttMode) {
                    ForEach(STTMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.menu)

                if settings.sttMode == .api {
                    Picker("STT Provider", selection: $settings.sttProviderId) {
                        Text("None").tag(Optional<UUID>.none)
                        ForEach(settings.providers) { provider in
                            Text(provider.name).tag(Optional(provider.id))
                        }
                    }
                    .pickerStyle(.menu)

                    TextField("STT Model ID", text: $settings.sttModel)
                        .textFieldStyle(.roundedBorder)
                } else {
                    Text("Uses on-device macOS speech recognition.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Speech-to-Text")
            }
            
            Section {
                HStack {
                    Text("Global Shortcut")
                    Spacer()
                    ShortcutRecorderView(name: .toggleOracle)
                        .frame(width: 160, height: 24)
                }
            } header: {
                Text("Shortcuts")
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 500, minHeight: 500)
        .sheet(item: $editingProvider) { provider in
            ProviderEditor(provider: provider) { updated in
                if let index = settings.providers.firstIndex(where: { $0.id == updated.id }) {
                    settings.providers[index] = updated
                } else {
                    settings.providers.append(updated)
                }
                settings.save()
                editingProvider = nil
            }
        }
        .sheet(isPresented: $showingAddProvider) {
            ProviderEditor(provider: nil) { newProvider in
                settings.providers.append(newProvider)
                settings.save()
                showingAddProvider = false
            }
        }
        .sheet(item: $editingModel) { model in
            ModelEditor(model: model, providers: settings.providers) { updated in
                if let index = settings.models.firstIndex(where: { $0.id == updated.id }) {
                    settings.models[index] = updated
                } else {
                    settings.models.append(updated)
                }
                if updated.isDefault {
                    for i in settings.models.indices {
                        if settings.models[i].id != updated.id {
                            settings.models[i].isDefault = false
                        }
                    }
                    settings.selectedModelId = updated.id
                }
                settings.save()
                editingModel = nil
            }
        }
        .sheet(isPresented: $showingAddModel) {
            ModelEditor(model: nil, providers: settings.providers) { newModel in
                settings.models.append(newModel)
                if newModel.isDefault {
                    for i in settings.models.indices {
                        if settings.models[i].id != newModel.id {
                            settings.models[i].isDefault = false
                        }
                    }
                    settings.selectedModelId = newModel.id
                }
                settings.save()
                showingAddModel = false
            }
        }
    }
    
    private func providerName(for id: UUID) -> String {
        appState.settings.providers.first { $0.id == id }?.name ?? "Unknown"
    }
}

struct ProviderRow: View {
    let provider: Provider
    let onEdit: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(provider.name)
                    .font(.system(size: 13, weight: .medium))
                Text(provider.baseURL)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button("Edit") { onEdit() }
                .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
}

struct ModelRow: View {
    let model: AIModel
    let providerName: String
    let onEdit: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.displayName)
                    .font(.system(size: 13, weight: .medium))
                Text("\(providerName) — \(model.modelId)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if model.isDefault {
                Text("Default")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(Capsule())
            }
            Spacer()
            Button("Edit") { onEdit() }
                .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
}

struct ProviderEditor: View {
    let provider: Provider?
    let onSave: (Provider) -> Void
    
    @State private var name: String = ""
    @State private var baseURL: String = ""
    @State private var apiKey: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text(provider == nil ? "Add Provider" : "Edit Provider")
                .font(.headline)
            
            Form {
                TextField("Name", text: $name)
                TextField("Base URL", text: $baseURL)
                    .textContentType(.URL)
                SecureField("API Key", text: $apiKey)
            }
            .frame(width: 360)
            
            HStack {
                Button("Cancel", role: .cancel) {
                    // dismiss handled by presentation
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Save") {
                    let p = provider ?? Provider(name: name, baseURL: baseURL)
                    var updated = p
                    updated.name = name
                    updated.baseURL = baseURL
                    try? KeychainHelper.save(key: updated.apiKeyIdentifier, value: apiKey)
                    onSave(updated)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || baseURL.isEmpty)
            }
        }
        .padding()
        .frame(width: 420)
        .onAppear {
            if let p = provider {
                name = p.name
                baseURL = p.baseURL
                apiKey = (try? KeychainHelper.read(key: p.apiKeyIdentifier)) ?? ""
            }
        }
    }
}

struct ModelEditor: View {
    let model: AIModel?
    let providers: [Provider]
    let onSave: (AIModel) -> Void
    
    @State private var providerId: UUID?
    @State private var modelId: String = ""
    @State private var displayName: String = ""
    @State private var isDefault: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text(model == nil ? "Add Model" : "Edit Model")
                .font(.headline)
            
            Form {
                Picker("Provider", selection: $providerId) {
                    ForEach(providers) { provider in
                        Text(provider.name).tag(Optional(provider.id))
                    }
                }
                TextField("Model ID", text: $modelId)
                    .textFieldStyle(.roundedBorder)
                TextField("Display Name", text: $displayName)
                    .textFieldStyle(.roundedBorder)
                Toggle("Set as Default", isOn: $isDefault)
            }
            .frame(width: 360)
            
            HStack {
                Button("Cancel", role: .cancel) { }
                .keyboardShortcut(.cancelAction)
                
                Button("Save") {
                    guard let pid = providerId else { return }
                    let m = model ?? AIModel(providerId: pid, modelId: modelId)
                    var updated = m
                    updated.providerId = pid
                    updated.modelId = modelId
                    updated.displayName = displayName.isEmpty ? modelId : displayName
                    updated.isDefault = isDefault
                    onSave(updated)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(providerId == nil || modelId.isEmpty)
            }
        }
        .padding()
        .frame(width: 420)
        .onAppear {
            if let m = model {
                providerId = m.providerId
                modelId = m.modelId
                displayName = m.displayName
                isDefault = m.isDefault
            } else if let first = providers.first {
                providerId = first.id
            }
        }
    }
}

struct ShortcutRecorderView: NSViewRepresentable {
    let name: KeyboardShortcuts.Name
    
    func makeNSView(context: Context) -> KeyboardShortcuts.RecorderCocoa {
        KeyboardShortcuts.RecorderCocoa(for: name)
    }
    
    func updateNSView(_ nsView: KeyboardShortcuts.RecorderCocoa, context: Context) {}
}
