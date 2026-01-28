import AppKit
import Foundation
import UniformTypeIdentifiers

/// Service for exporting events to ICS format as fallback
final class ICSExportService {
    /// Export an event to ICS format and save to file
    /// - Parameters:
    ///   - event: The event to export
    ///   - url: Optional URL to save to. If nil, will prompt user.
    /// - Returns: The URL where the file was saved
    func exportEvent(_ event: ParsedEvent, to url: URL? = nil) throws -> URL {
        let icsContent = generateICS(for: event)

        let saveURL: URL
        if let url = url {
            saveURL = url
        } else {
            // Use save panel
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.init(filenameExtension: "ics")!]
            panel.nameFieldStringValue = "\(sanitizeFilename(event.title)).ics"
            panel.title = "Save Calendar Event"

            guard panel.runModal() == .OK, let selectedURL = panel.url else {
                throw AppError.eventCreationFailed("Export cancelled")
            }
            saveURL = selectedURL
        }

        try icsContent.write(to: saveURL, atomically: true, encoding: .utf8)
        return saveURL
    }

    /// Generate ICS content for an event
    private func generateICS(for event: ParsedEvent) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")

        let allDayFormatter = DateFormatter()
        allDayFormatter.dateFormat = "yyyyMMdd"

        let now = dateFormatter.string(from: Date())
        let uid = "\(event.id.uuidString)@screentocalendar"

        var lines: [String] = [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:-//Screen to Calendar//EN",
            "CALSCALE:GREGORIAN",
            "METHOD:PUBLISH",
            "BEGIN:VEVENT",
            "UID:\(uid)",
            "DTSTAMP:\(now)"
        ]

        if event.isAllDay {
            lines.append("DTSTART;VALUE=DATE:\(allDayFormatter.string(from: event.startDate))")
            lines.append("DTEND;VALUE=DATE:\(allDayFormatter.string(from: event.effectiveEndDate))")
        } else {
            lines.append("DTSTART:\(dateFormatter.string(from: event.startDate))")
            lines.append("DTEND:\(dateFormatter.string(from: event.effectiveEndDate))")
        }

        lines.append("SUMMARY:\(escapeICSText(event.title))")

        if let location = event.location, !location.isEmpty {
            lines.append("LOCATION:\(escapeICSText(location))")
        }

        if let notes = event.notes, !notes.isEmpty {
            lines.append("DESCRIPTION:\(escapeICSText(notes))")
        }

        if let url = event.url {
            lines.append("URL:\(url.absoluteString)")
        }

        lines.append(contentsOf: [
            "END:VEVENT",
            "END:VCALENDAR"
        ])

        return lines.joined(separator: "\r\n")
    }

    /// Escape special characters for ICS format
    private func escapeICSText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    /// Sanitize filename
    private func sanitizeFilename(_ name: String) -> String {
        let invalidChars = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        return name.components(separatedBy: invalidChars).joined(separator: "_")
    }

    /// Open an ICS file in the default application (usually Calendar.app)
    func openICSFile(at url: URL) {
        NSWorkspace.shared.open(url)
    }
}
