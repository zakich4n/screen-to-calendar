import Foundation

/// LLM provider using Anthropic Claude API
final class AnthropicLLMProvider: LLMProvider {
    private let settings = AppSettings.shared

    func parseEvent(from text: String) async throws -> ParsedEvent {
        guard let apiKey = KeychainHelper.getAPIKey(for: .anthropic), !apiKey.isEmpty else {
            throw AppError.apiKeyMissing("Anthropic")
        }

        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw AppError.llmFailed("Invalid URL")
        }

        let prompt = LLMPrompts.eventExtractionPrompt(text: text)

        let requestBody: [String: Any] = [
            "model": settings.anthropicModel,
            "max_tokens": 1024,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "system": "You are a helpful assistant that extracts calendar event information from text. Always respond with valid JSON only, no markdown code blocks or other text."
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.llmFailed("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw AppError.llmFailed("Anthropic error: \(message)")
            }
            throw AppError.llmFailed("Anthropic error (\(httpResponse.statusCode))")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let text = firstBlock["text"] as? String else {
            throw AppError.llmFailed("Failed to parse Anthropic response")
        }

        return try LLMPrompts.parseResponse(text, sourceText: text)
    }
}
