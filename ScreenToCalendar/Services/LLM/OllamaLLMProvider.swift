import Foundation

/// LLM provider using local Ollama instance
final class OllamaLLMProvider: LLMProvider {
    private let settings = AppSettings.shared

    func parseEvent(from text: String) async throws -> ParsedEvent {
        let host = settings.ollamaHost.trimmingCharacters(in: .init(charactersIn: "/"))
        guard let url = URL(string: "\(host)/api/generate") else {
            throw AppError.llmFailed("Invalid Ollama host URL")
        }

        let prompt = LLMPrompts.eventExtractionPrompt(
            text: text,
            customContext: settings.customPromptContext
        )

        // Get model, auto-selecting first available if current is empty or invalid
        var model = settings.ollamaModel
        if model.isEmpty {
            model = try await getFirstAvailableModel()
            await MainActor.run { settings.ollamaModel = model }
        }

        #if DEBUG
        print("[Ollama] Using model: '\(model)' at host: '\(host)'")
        #endif

        let requestBody: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": false,
            "format": "json",
            "options": [
                "num_ctx": 4096
            ],
            "think": false  // Skip reasoning for models like deepseek-r1
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 180  // 3 minutes for larger models

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.llmFailed("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 404 {
                throw AppError.llmFailed("Model '\(model)' not found. Please select a different model in Settings.")
            }
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AppError.llmFailed("Ollama error (\(httpResponse.statusCode)): \(errorMessage)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let responseText = json["response"] as? String else {
            throw AppError.llmFailed("Failed to parse Ollama response")
        }

        #if DEBUG
        print("[Ollama] Input text: \(text.prefix(100))...")
        print("[Ollama] Raw response: \(responseText)")
        #endif

        return try LLMPrompts.parseResponse(responseText, sourceText: text)
    }

    /// Get the first available model from Ollama
    private func getFirstAvailableModel() async throws -> String {
        do {
            let models = try await OllamaService.fetchAvailableModels()
            guard let firstModel = models.first else {
                throw AppError.llmFailed("No Ollama models installed. Run 'ollama pull <model>' to install one.")
            }
            return firstModel
        } catch {
            throw AppError.llmFailed("Failed to get Ollama models: \(error.localizedDescription)")
        }
    }
}
