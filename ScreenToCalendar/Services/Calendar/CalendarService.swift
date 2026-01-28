import EventKit
import Foundation

/// Service for creating calendar events using EventKit
final class CalendarService {
    private let eventStore = EKEventStore()

    /// Request full access to calendars
    func requestAccess() async throws -> Bool {
        return try await eventStore.requestFullAccessToEvents()
    }

    /// Check if we have calendar access
    var hasAccess: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    /// Get available calendars for events
    func getCalendars() -> [EKCalendar] {
        eventStore.calendars(for: .event)
            .filter { $0.allowsContentModifications }
    }

    /// Get the default calendar
    var defaultCalendar: EKCalendar? {
        eventStore.defaultCalendarForNewEvents
    }

    /// Create a calendar event
    /// - Parameter parsedEvent: The event data to create
    func createEvent(_ parsedEvent: ParsedEvent) async throws {
        // Request access if needed
        let hasAccess = try await requestAccess()
        guard hasAccess else {
            throw AppError.calendarAccessDenied
        }

        // Create event
        let event = EKEvent(eventStore: eventStore)
        event.title = parsedEvent.title
        event.startDate = parsedEvent.startDate
        event.isAllDay = parsedEvent.isAllDay

        if parsedEvent.isAllDay {
            // For all-day events, end date should be the same day
            event.endDate = parsedEvent.startDate
        } else {
            event.endDate = parsedEvent.effectiveEndDate
        }

        if let location = parsedEvent.location, !location.isEmpty {
            event.location = location
        }

        if let notes = parsedEvent.notes, !notes.isEmpty {
            event.notes = notes
        }

        if let url = parsedEvent.url {
            event.url = url
        }

        // Set calendar
        if let calendarIdentifier = parsedEvent.calendarIdentifier,
           let calendar = eventStore.calendar(withIdentifier: calendarIdentifier) {
            event.calendar = calendar
        } else {
            event.calendar = eventStore.defaultCalendarForNewEvents
        }

        guard event.calendar != nil else {
            throw AppError.eventCreationFailed("No calendar available")
        }

        // Save event
        do {
            try eventStore.save(event, span: .thisEvent)
        } catch {
            throw AppError.eventCreationFailed(error.localizedDescription)
        }

        // Show notification if enabled
        if AppSettings.shared.showNotificationOnEventCreated {
            await showNotification(for: parsedEvent)
        }
    }

    /// Show a notification for the created event
    @MainActor
    private func showNotification(for event: ParsedEvent) {
        // UNUserNotificationCenter requires a valid bundle identifier
        guard Bundle.main.bundleIdentifier != nil else {
            #if DEBUG
            print("[CalendarService] Skipping notification - no bundle identifier (running outside app bundle)")
            #endif
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Event Created"
        content.body = event.title
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { _ in }
    }
}

import UserNotifications
