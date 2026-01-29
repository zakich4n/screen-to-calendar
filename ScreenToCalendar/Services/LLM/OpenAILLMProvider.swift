import Foundation

/// LLM provider using OpenAI API
final class OpenAILLMProvider: LLMProvider {
    private let settings = AppSettings.shared

    func parseEvent(from text: String) async throws -> ParsedEvent {
        guard let apiKey = KeychainHelper.getAPIKey(for: .openAI), !apiKey.isEmpty else {
            throw AppError.apiKeyMissing("OpenAI")
        }

        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw AppError.llmFailed("Invalid URL")
        }

        let prompt = LLMPrompts.eventExtractionPrompt(
            text: text,
            customContext: settings.customPromptContext
        )

        let requestBody: [String: Any] = [
            "model": settings.openAIModel,
            "messages": [
                [
                    "role": "system",
                    "content": "You are a helpful assistant that extracts calendar event information from text. Always respond with valid JSON only."
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "response_format": ["type": "json_object"],
            "temperature": 0.1
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
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
                throw AppError.llmFailed("OpenAI error: \(message)")
            }
            throw AppError.llmFailed("OpenAI error (\(httpResponse.statusCode))")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AppError.llmFailed("Failed to parse OpenAI response")
        }

        return try LLMPrompts.parseResponse(content, sourceText: text)
    }
}
