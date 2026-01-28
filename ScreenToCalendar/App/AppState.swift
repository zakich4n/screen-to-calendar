import Foundation
import SwiftUI
import Combine

/// Global application state
@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    // MARK: - Processing State

    @Published var isProcessing = false
    @Published var processingMessage: String?
    @Published var lastError: AppError?

    // MARK: - Event State

    @Published var currentParsedEvent: ParsedEvent?
    @Published var showEventForm = false

    // MARK: - Services

    let clipboardService = ClipboardService()
    let screenCaptureService = ScreenCaptureService()
    let calendarService = CalendarService()

    private var ocrProvider: OCRProvider {
        switch AppSettings.shared.selectedOCRProvider {
        case .appleVision:
            return VisionOCRProvider()
        case .ollama:
            return OllamaOCRProvider()
        }
    }

    private var llmProvider: LLMProvider {
        switch AppSettings.shared.selectedLLMProvider {
        case .ollama:
            return OllamaLLMProvider()
        case .openAI:
            return OpenAILLMProvider()
        case .anthropic:
            return AnthropicLLMProvider()
        }
    }

    private init() {}

    // MARK: - Actions

    /// Process text from clipboard
    func processClipboardText() async {
        isProcessing = true
        processingMessage = "Reading clipboard..."
        lastError = nil

        do {
            guard let text = clipboardService.getText() else {
                throw AppError.noTextInClipboard
            }

            processingMessage = "Analyzing text..."
            let event = try await parseEventFromText(text)

            currentParsedEvent = event
            showEventForm = true
        } catch {
            lastError = AppError.from(error)
        }

        isProcessing = false
        processingMessage = nil
    }

    /// Capture screenshot and process
    func processScreenshot() async {
        isProcessing = true
        processingMessage = "Capturing screen..."
        lastError = nil

        do {
            guard let image = try await screenCaptureService.captureInteractiveScreenshot() else {
                throw AppError.screenshotFailed
            }

            processingMessage = "Extracting text (OCR)..."
            let text = try await ocrProvider.recognizeText(from: image)

            guard !text.isEmpty else {
                throw AppError.noTextFound
            }

            processingMessage = "Analyzing text..."
            let event = try await parseEventFromText(text)

            currentParsedEvent = event
            showEventForm = true
        } catch {
            lastError = AppError.from(error)
        }

        isProcessing = false
        processingMessage = nil
    }

    /// Parse text into a calendar event using LLM
    private func parseEventFromText(_ text: String) async throws -> ParsedEvent {
        let response = try await llmProvider.parseEvent(from: text)
        return response
    }

    /// Save event to calendar
    func saveEvent(_ event: ParsedEvent) async throws {
        try await calendarService.createEvent(event)
    }

    /// Clear current state
    func clearCurrentEvent() {
        currentParsedEvent = nil
        showEventForm = false
        lastError = nil
    }
}

// MARK: - App Errors

enum AppError: LocalizedError {
    case noTextInClipboard
    case screenshotFailed
    case noTextFound
    case ocrFailed(String)
    case llmFailed(String)
    case calendarAccessDenied
    case eventCreationFailed(String)
    case networkError(String)
    case apiKeyMissing(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .noTextInClipboard:
            return "No text found in clipboard"
        case .screenshotFailed:
            return "Failed to capture screenshot"
        case .noTextFound:
            return "No text found in the image"
        case .ocrFailed(let detail):
            return "OCR failed: \(detail)"
        case .llmFailed(let detail):
            return "Failed to parse event: \(detail)"
        case .calendarAccessDenied:
            return "Calendar access denied. Please grant permission in System Settings."
        case .eventCreationFailed(let detail):
            return "Failed to create event: \(detail)"
        case .networkError(let detail):
            return "Network error: \(detail)"
        case .apiKeyMissing(let provider):
            return "API key missing for \(provider)"
        case .unknown(let detail):
            return "Error: \(detail)"
        }
    }

    static func from(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }
        return .unknown(error.localizedDescription)
    }
}
