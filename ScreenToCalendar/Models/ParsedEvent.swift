import Foundation

/// Represents a calendar event parsed from text or screenshot
struct ParsedEvent: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var startDate: Date
    var endDate: Date?
    var isAllDay: Bool
    var location: String?
    var notes: String?
    var url: URL?
    var calendarIdentifier: String?

    /// Raw text that was used to parse this event
    var sourceText: String?

    init(
        id: UUID = UUID(),
        title: String,
        startDate: Date,
        endDate: Date? = nil,
        isAllDay: Bool = false,
        location: String? = nil,
        notes: String? = nil,
        url: URL? = nil,
        calendarIdentifier: String? = nil,
        sourceText: String? = nil
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.location = location
        self.notes = notes
        self.url = url
        self.calendarIdentifier = calendarIdentifier
        self.sourceText = sourceText
    }

    /// Computed duration in minutes
    var durationMinutes: Int? {
        guard let endDate = endDate else { return nil }
        return Int(endDate.timeIntervalSince(startDate) / 60)
    }

    /// Returns the end date or a default 1-hour duration
    var effectiveEndDate: Date {
        endDate ?? startDate.addingTimeInterval(3600)
    }
}

/// Response from LLM when parsing event data
struct LLMEventResponse: Codable {
    let title: String?
    let date: String?
    let startTime: String?
    let endTime: String?
    let location: String?
    let notes: String?
    let isAllDay: Bool?

    enum CodingKeys: String, CodingKey {
        case title
        case date
        case startTime = "start_time"
        case endTime = "end_time"
        case location
        case notes
        case isAllDay = "is_all_day"
    }
}
