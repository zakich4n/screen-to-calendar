import AppKit

/// Service for reading text from the system clipboard
final class ClipboardService {
    private let pasteboard = NSPasteboard.general

    /// Get text content from clipboard
    /// - Returns: The text content if available, nil otherwise
    func getText() -> String? {
        guard let text = pasteboard.string(forType: .string) else {
            return nil
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : text
    }

    /// Get image from clipboard
    /// - Returns: NSImage if available, nil otherwise
    func getImage() -> NSImage? {
        if let data = pasteboard.data(forType: .tiff) {
            return NSImage(data: data)
        }
        if let data = pasteboard.data(forType: .png) {
            return NSImage(data: data)
        }
        return nil
    }

    /// Check if clipboard contains text
    var hasText: Bool {
        pasteboard.types?.contains(.string) ?? false
    }

    /// Check if clipboard contains an image
    var hasImage: Bool {
        pasteboard.types?.contains(.tiff) ?? false ||
        pasteboard.types?.contains(.png) ?? false
    }

    /// Get the most recent content type
    var contentType: ClipboardContentType {
        if hasText {
            return .text
        } else if hasImage {
            return .image
        }
        return .empty
    }
}

enum ClipboardContentType {
    case text
    case image
    case empty
}
