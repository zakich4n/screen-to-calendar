import AppKit
import KeyboardShortcuts

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from dock (menu bar app only)
        NSApp.setActivationPolicy(.accessory)

        setupDefaultShortcuts()
        setupKeyboardShortcutHandlers()
    }

    private func setupDefaultShortcuts() {
        // Set default shortcuts if not already configured
        if KeyboardShortcuts.getShortcut(for: .captureText) == nil {
            KeyboardShortcuts.setShortcut(.init(.e, modifiers: [.command, .shift]), for: .captureText)
        }

        if KeyboardShortcuts.getShortcut(for: .captureScreenshot) == nil {
            KeyboardShortcuts.setShortcut(.init(.s, modifiers: [.command, .shift]), for: .captureScreenshot)
        }
    }

    private func setupKeyboardShortcutHandlers() {
        KeyboardShortcuts.onKeyUp(for: .captureText) {
            Task { @MainActor in
                await AppState.shared.processClipboardText()
            }
        }

        KeyboardShortcuts.onKeyUp(for: .captureScreenshot) {
            Task { @MainActor in
                await AppState.shared.processScreenshot()
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
