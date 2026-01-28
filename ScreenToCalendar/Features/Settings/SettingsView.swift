import SwiftUI
import KeyboardShortcuts
import KeychainAccess

struct SettingsView: View {
    var body: some View {
        TabView {
            ProvidersSettingsView()
                .tabItem {
                    Label("Providers", systemImage: "cpu")
                }

            APIKeysSettingsView()
                .tabItem {
                    Label("API Keys", systemImage: "key")
                }

            ShortcutsSettingsView()
                .tabItem {
                    Label("Shortcuts", systemImage: "command")
                }

            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
        }
        .frame(width: 500, height: 350)
    }
}

// MARK: - Providers Settings

struct ProvidersSettingsView: View {
    @EnvironmentObject var settings: AppSettings

    @State private var availableOllamaModels: [String] = []
    @State private var isLoadingModels = false
    @State private var modelLoadError: String?
    @State private var showManualModelEntry = false

    var body: some View {
        Form {
            Section("LLM Provider") {
                Picker("Provider", selection: $settings.selectedLLMProvider) {
                    ForEach(LLMProviderType.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }

                switch settings.selectedLLMProvider {
                case .ollama:
                    TextField("Ollama Host", text: $settings.ollamaHost)
                    ollamaModelPicker
                case .openAI:
                    TextField("Model", text: $settings.openAIModel)
                        .help("e.g., gpt-4o-mini, gpt-4o")
                case .anthropic:
                    TextField("Model", text: $settings.anthropicModel)
                        .help("e.g., claude-3-5-sonnet-latest")
                }
            }

            Section("OCR Provider") {
                Picker("Provider", selection: $settings.selectedOCRProvider) {
                    ForEach(OCRProviderType.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }

                if settings.selectedOCRProvider == .ollama {
                    ollamaVisionModelPicker
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onChange(of: settings.selectedLLMProvider) { _, newValue in
            if newValue == .ollama {
                loadOllamaModels()
            }
        }
        .onChange(of: settings.selectedOCRProvider) { _, newValue in
            if newValue == .ollama && availableOllamaModels.isEmpty {
                loadOllamaModels()
            }
        }
        .onAppear {
            if settings.selectedLLMProvider == .ollama || settings.selectedOCRProvider == .ollama {
                loadOllamaModels()
            }
        }
    }

    @ViewBuilder
    private var ollamaModelPicker: some View {
        if isLoadingModels {
            HStack {
                Text("Model")
                Spacer()
                ProgressView()
                    .scaleEffect(0.7)
            }
        } else if showManualModelEntry || availableOllamaModels.isEmpty {
            HStack {
                TextField("Model", text: $settings.ollamaModel)
                    .help("e.g., llama3.2, mistral, phi3")
                refreshButton
            }
            if let error = modelLoadError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            HStack {
                Picker("Model", selection: $settings.ollamaModel) {
                    ForEach(availableOllamaModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                refreshButton
            }
        }
    }

    @ViewBuilder
    private var ollamaVisionModelPicker: some View {
        if isLoadingModels {
            HStack {
                Text("Vision Model")
                Spacer()
                ProgressView()
                    .scaleEffect(0.7)
            }
        } else if showManualModelEntry || availableOllamaModels.isEmpty {
            HStack {
                TextField("Vision Model", text: $settings.ollamaVisionModel)
                    .help("e.g., llava, bakllava")
                refreshButton
            }
        } else {
            HStack {
                Picker("Vision Model", selection: $settings.ollamaVisionModel) {
                    ForEach(availableOllamaModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                refreshButton
            }
        }
    }

    private var refreshButton: some View {
        Button {
            loadOllamaModels()
        } label: {
            Image(systemName: "arrow.clockwise")
        }
        .buttonStyle(.plain)
        .disabled(isLoadingModels)
        .help("Refresh model list")
    }

    private func loadOllamaModels() {
        isLoadingModels = true
        modelLoadError = nil
        showManualModelEntry = false

        Task {
            do {
                let models = try await OllamaService.fetchAvailableModels()
                await MainActor.run {
                    availableOllamaModels = models
                    isLoadingModels = false

                    // If current model isn't in list, add it or show manual entry
                    if !settings.ollamaModel.isEmpty && !models.contains(settings.ollamaModel) {
                        availableOllamaModels.insert(settings.ollamaModel, at: 0)
                    }
                    if !settings.ollamaVisionModel.isEmpty && !models.contains(settings.ollamaVisionModel) {
                        if !availableOllamaModels.contains(settings.ollamaVisionModel) {
                            availableOllamaModels.insert(settings.ollamaVisionModel, at: 0)
                        }
                    }

                    // Select first model if none selected
                    if settings.ollamaModel.isEmpty, let first = models.first {
                        settings.ollamaModel = first
                    }
                }
            } catch {
                await MainActor.run {
                    isLoadingModels = false
                    modelLoadError = error.localizedDescription
                    showManualModelEntry = true
                }
            }
        }
    }
}

// MARK: - API Keys Settings

struct APIKeysSettingsView: View {
    @State private var openAIKey = ""
    @State private var anthropicKey = ""
    @State private var showOpenAIKey = false
    @State private var showAnthropicKey = false
    @State private var saveStatus: String?

    private let keychain = Keychain(service: "com.screentocalendar.app")

    var body: some View {
        Form {
            Section("OpenAI") {
                HStack {
                    if showOpenAIKey {
                        TextField("API Key", text: $openAIKey)
                    } else {
                        SecureField("API Key", text: $openAIKey)
                    }
                    Button {
                        showOpenAIKey.toggle()
                    } label: {
                        Image(systemName: showOpenAIKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.plain)
                }
                Text("Get your API key from platform.openai.com")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Anthropic") {
                HStack {
                    if showAnthropicKey {
                        TextField("API Key", text: $anthropicKey)
                    } else {
                        SecureField("API Key", text: $anthropicKey)
                    }
                    Button {
                        showAnthropicKey.toggle()
                    } label: {
                        Image(systemName: showAnthropicKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.plain)
                }
                Text("Get your API key from console.anthropic.com")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Button("Save Keys") {
                        saveKeys()
                    }
                    .buttonStyle(.borderedProminent)

                    if let status = saveStatus {
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            loadKeys()
        }
    }

    private func loadKeys() {
        openAIKey = (try? keychain.get("openai_api_key")) ?? ""
        anthropicKey = (try? keychain.get("anthropic_api_key")) ?? ""
    }

    private func saveKeys() {
        do {
            if openAIKey.isEmpty {
                try keychain.remove("openai_api_key")
            } else {
                try keychain.set(openAIKey, key: "openai_api_key")
            }

            if anthropicKey.isEmpty {
                try keychain.remove("anthropic_api_key")
            } else {
                try keychain.set(anthropicKey, key: "anthropic_api_key")
            }

            saveStatus = "Saved!"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                saveStatus = nil
            }
        } catch {
            saveStatus = "Error saving keys"
        }
    }
}

// MARK: - Shortcuts Settings

struct ShortcutsSettingsView: View {
    var body: some View {
        Form {
            Section("Keyboard Shortcuts") {
                KeyboardShortcuts.Recorder("Capture from Clipboard", name: .captureText)
                KeyboardShortcuts.Recorder("Capture Screenshot", name: .captureScreenshot)
            }

            Section {
                Text("Configure global keyboard shortcuts to quickly create calendar events.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Form {
            Section("Event Defaults") {
                Picker("Default Duration", selection: $settings.defaultEventDuration) {
                    Text("30 minutes").tag(30)
                    Text("1 hour").tag(60)
                    Text("1.5 hours").tag(90)
                    Text("2 hours").tag(120)
                }
            }

            Section("Behavior") {
                Toggle("Show notification when event created", isOn: $settings.showNotificationOnEventCreated)
                Toggle("Close form after saving", isOn: $settings.closeFormAfterSave)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Keychain Helper

struct KeychainHelper {
    private static let keychain = Keychain(service: "com.screentocalendar.app")

    static func getAPIKey(for provider: LLMProviderType) -> String? {
        switch provider {
        case .ollama:
            return nil
        case .openAI:
            return try? keychain.get("openai_api_key")
        case .anthropic:
            return try? keychain.get("anthropic_api_key")
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppSettings.shared)
}
