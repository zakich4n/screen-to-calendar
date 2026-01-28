import Foundation

/// Protocol for LLM providers that parse event information from text
protocol LLMProvider {
    /// Parse text and extract calendar event information
    /// - Parameter text: The text to parse
    /// - Returns: A parsed event with extracted information
    func parseEvent(from text: String) async throws -> ParsedEvent
}

/// Common prompt template for event extraction
enum LLMPrompts {
    static func eventExtractionPrompt(text: String, currentDate: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: currentDate)

        formatter.dateFormat = "EEEE"
        let dayOfWeek = formatter.string(from: currentDate)

        return """
        Today is \(dayOfWeek), \(today).

        Extract calendar event information from the following text. Return a JSON object with these fields:
        - title: string (required) - the event title/name
        - date: string (required) - date in YYYY-MM-DD format
        - start_time: string (optional) - start time in HH:MM format (24h)
        - end_time: string (optional) - end time in HH:MM format (24h)
        - location: string (optional) - event location
        - notes: string (optional) - additional details
        - is_all_day: boolean (optional) - true if this is an all-day event

        If a date is mentioned relatively (e.g., "tomorrow", "next Monday"), calculate the actual date.
        If no time is specified, assume it's an all-day event.

        Return ONLY valid JSON, no other text.

        Text to parse:
        \(text)
        """
    }

    /// Parse JSON response into ParsedEvent
    static func parseResponse(_ json: String, sourceText: String) throws -> ParsedEvent {
        // Extract JSON from response (handle markdown code blocks)
        var cleanedJson = json
        if let jsonStart = json.range(of: "{"),
           let jsonEnd = json.range(of: "}", options: .backwards) {
            cleanedJson = String(json[jsonStart.lowerBound..<jsonEnd.upperBound])
        }

        guard let data = cleanedJson.data(using: .utf8) else {
            throw AppError.llmFailed("Invalid response encoding")
        }

        // Check for empty response
        let trimmedJson = cleanedJson.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedJson == "{}" || trimmedJson == "{ }" {
            throw AppError.llmFailed("Model returned empty response. Try a different model (reasoning models like deepseek-r1 may not work well for structured extraction).")
        }

        let response: LLMEventResponse
        do {
            response = try JSONDecoder().decode(LLMEventResponse.self, from: data)
        } catch {
            throw AppError.llmFailed("Failed to decode JSON: \(error.localizedDescription). Response: \(cleanedJson.prefix(200))")
        }

        guard let title = response.title, !title.isEmpty else {
            throw AppError.llmFailed("Could not extract event title from response: \(cleanedJson.prefix(200))")
        }

        // Parse date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        guard let dateString = response.date,
              let date = dateFormatter.date(from: dateString) else {
            throw AppError.llmFailed("Could not extract event date. Got: '\(response.date ?? "nil")' from response: \(cleanedJson.prefix(200))")
        }

        // Parse times
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        var startDate = date
        var endDate: Date? = nil
        let isAllDay = response.isAllDay ?? (response.startTime == nil)

        if !isAllDay, let startTimeStr = response.startTime,
           let startTime = timeFormatter.date(from: startTimeStr) {
            let calendar = Calendar.current
            let timeComponents = calendar.dateComponents([.hour, .minute], from: startTime)
            startDate = calendar.date(bySettingHour: timeComponents.hour ?? 0,
                                       minute: timeComponents.minute ?? 0,
                                       second: 0,
                                       of: date) ?? date

            if let endTimeStr = response.endTime,
               let endTime = timeFormatter.date(from: endTimeStr) {
                let endComponents = calendar.dateComponents([.hour, .minute], from: endTime)
                endDate = calendar.date(bySettingHour: endComponents.hour ?? 0,
                                         minute: endComponents.minute ?? 0,
                                         second: 0,
                                         of: date)
            } else {
                // Default 1 hour duration
                endDate = startDate.addingTimeInterval(3600)
            }
        }

        return ParsedEvent(
            title: title,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            location: response.location,
            notes: response.notes,
            sourceText: sourceText
        )
    }
}
