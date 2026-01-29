import Combine
import Foundation
import KeyboardShortcuts

/// User preferences and configuration
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // MARK: - LLM Provider Settings

    @Published var selectedLLMProvider: LLMProviderType {
        didSet { UserDefaults.standard.set(selectedLLMProvider.rawValue, forKey: Keys.selectedLLMProvider) }
    }

    @Published var ollamaModel: String {
        didSet { UserDefaults.standard.set(ollamaModel, forKey: Keys.ollamaModel) }
    }

    @Published var ollamaHost: String {
        didSet { UserDefaults.standard.set(ollamaHost, forKey: Keys.ollamaHost) }
    }

    @Published var openAIModel: String {
        didSet { UserDefaults.standard.set(openAIModel, forKey: Keys.openAIModel) }
    }

    @Published var anthropicModel: String {
        didSet { UserDefaults.standard.set(anthropicModel, forKey: Keys.anthropicModel) }
    }

    // MARK: - OCR Provider Settings

    @Published var selectedOCRProvider: OCRProviderType {
        didSet { UserDefaults.standard.set(selectedOCRProvider.rawValue, forKey: Keys.selectedOCRProvider) }
    }

    @Published var ollamaVisionModel: String {
        didSet { UserDefaults.standard.set(ollamaVisionModel, forKey: Keys.ollamaVisionModel) }
    }

    // MARK: - Calendar Settings

    @Published var defaultCalendarIdentifier: String? {
        didSet { UserDefaults.standard.set(defaultCalendarIdentifier, forKey: Keys.defaultCalendar) }
    }

    @Published var defaultEventDuration: Int {
        didSet { UserDefaults.standard.set(defaultEventDuration, forKey: Keys.defaultEventDuration) }
    }

    // MARK: - General Settings

    @Published var showNotificationOnEventCreated: Bool {
        didSet { UserDefaults.standard.set(showNotificationOnEventCreated, forKey: Keys.showNotification) }
    }

    @Published var closeFormAfterSave: Bool {
        didSet { UserDefaults.standard.set(closeFormAfterSave, forKey: Keys.closeFormAfterSave) }
    }

    @Published var customPromptContext: String {
        didSet { UserDefaults.standard.set(customPromptContext, forKey: Keys.customPromptContext) }
    }

    private init() {
        // Load saved settings or use defaults
        self.selectedLLMProvider = LLMProviderType(rawValue: UserDefaults.standard.string(forKey: Keys.selectedLLMProvider) ?? "") ?? .ollama
        self.ollamaModel = UserDefaults.standard.string(forKey: Keys.ollamaModel) ?? ""
        self.ollamaHost = UserDefaults.standard.string(forKey: Keys.ollamaHost) ?? "http://localhost:11434"
        self.openAIModel = UserDefaults.standard.string(forKey: Keys.openAIModel) ?? "gpt-4o-mini"
        self.anthropicModel = UserDefaults.standard.string(forKey: Keys.anthropicModel) ?? "claude-3-5-sonnet-latest"

        self.selectedOCRProvider = OCRProviderType(rawValue: UserDefaults.standard.string(forKey: Keys.selectedOCRProvider) ?? "") ?? .appleVision
        self.ollamaVisionModel = UserDefaults.standard.string(forKey: Keys.ollamaVisionModel) ?? ""

        self.defaultCalendarIdentifier = UserDefaults.standard.string(forKey: Keys.defaultCalendar)
        self.defaultEventDuration = UserDefaults.standard.object(forKey: Keys.defaultEventDuration) as? Int ?? 60

        self.showNotificationOnEventCreated = UserDefaults.standard.object(forKey: Keys.showNotification) as? Bool ?? true
        self.closeFormAfterSave = UserDefaults.standard.object(forKey: Keys.closeFormAfterSave) as? Bool ?? true
        self.customPromptContext = UserDefaults.standard.string(forKey: Keys.customPromptContext) ?? ""
    }

    private enum Keys {
        static let selectedLLMProvider = "selectedLLMProvider"
        static let ollamaModel = "ollamaModel"
        static let ollamaHost = "ollamaHost"
        static let openAIModel = "openAIModel"
        static let anthropicModel = "anthropicModel"
        static let selectedOCRProvider = "selectedOCRProvider"
        static let ollamaVisionModel = "ollamaVisionModel"
        static let defaultCalendar = "defaultCalendar"
        static let defaultEventDuration = "defaultEventDuration"
        static let showNotification = "showNotificationOnEventCreated"
        static let closeFormAfterSave = "closeFormAfterSave"
        static let customPromptContext = "customPromptContext"
    }
}

// MARK: - Provider Types

enum LLMProviderType: String, CaseIterable, Identifiable {
    case ollama = "ollama"
    case openAI = "openai"
    case anthropic = "anthropic"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ollama: return "Ollama (Local)"
        case .openAI: return "OpenAI"
        case .anthropic: return "Anthropic"
        }
    }

    var requiresAPIKey: Bool {
        switch self {
        case .ollama: return false
        case .openAI, .anthropic: return true
        }
    }
}

enum OCRProviderType: String, CaseIterable, Identifiable {
    case appleVision = "vision"
    case ollama = "ollama"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .appleVision: return "Apple Vision (Free, Local)"
        case .ollama: return "Ollama + LLaVA"
        }
    }
}

// MARK: - Keyboard Shortcuts Extension

extension KeyboardShortcuts.Name {
    static let captureText = Self("captureText")
    static let captureScreenshot = Self("captureScreenshot")
}
