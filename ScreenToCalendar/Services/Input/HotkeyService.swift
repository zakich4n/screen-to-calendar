import AppKit
import Foundation
import KeyboardShortcuts

/// Service for managing global keyboard shortcuts
/// Note: Most hotkey functionality is handled by KeyboardShortcuts package
/// and configured in AppDelegate
final class HotkeyService {
    static let shared = HotkeyService()

    private init() {}

    /// Get the current shortcut for text capture
    var textCaptureShortcut: KeyboardShortcuts.Shortcut? {
        KeyboardShortcuts.getShortcut(for: .captureText)
    }

    /// Get the current shortcut for screenshot capture
    var screenshotShortcut: KeyboardShortcuts.Shortcut? {
        KeyboardShortcuts.getShortcut(for: .captureScreenshot)
    }

    /// Reset shortcuts to defaults
    func resetToDefaults() {
        KeyboardShortcuts.setShortcut(.init(.e, modifiers: [.command, .shift]), for: .captureText)
        KeyboardShortcuts.setShortcut(.init(.s, modifiers: [.command, .shift]), for: .captureScreenshot)
    }

    /// Clear all shortcuts
    func clearAllShortcuts() {
        KeyboardShortcuts.setShortcut(nil, for: .captureText)
        KeyboardShortcuts.setShortcut(nil, for: .captureScreenshot)
    }
}
