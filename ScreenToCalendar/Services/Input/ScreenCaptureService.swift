import AppKit
import ScreenCaptureKit

/// Service for capturing screenshots using ScreenCaptureKit
final class ScreenCaptureService {
    /// Capture an interactive screenshot using the system screenshot UI
    /// This uses the macOS Sonoma+ API for interactive screen capture
    @MainActor
    func captureInteractiveScreenshot() async throws -> NSImage? {
        // Use SCScreenshotManager for macOS 14+
        if #available(macOS 14.0, *) {
            return try await captureWithContentPicker()
        } else {
            // Fallback for older macOS
            return try await captureWithScreenshotProcess()
        }
    }

    /// Capture using SCContentSharingPicker (macOS 14+)
    @available(macOS 14.0, *)
    @MainActor
    private func captureWithContentPicker() async throws -> NSImage? {
        // Check permission first
        let hasPermission = try await checkScreenCapturePermission()
        guard hasPermission else {
            throw AppError.screenshotFailed
        }

        // Get shareable content
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        guard let display = content.displays.first else {
            throw AppError.screenshotFailed
        }

        // Create filter for full display
        let filter = SCContentFilter(display: display, excludingWindows: [])

        // Configure capture
        let configuration = SCStreamConfiguration()
        configuration.width = display.width * 2
        configuration.height = display.height * 2
        configuration.scalesToFit = false
        configuration.showsCursor = false

        // Capture screenshot
        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        )

        return NSImage(cgImage: image, size: NSSize(width: display.width, height: display.height))
    }

    /// Fallback using screencapture command
    @MainActor
    private func captureWithScreenshotProcess() async throws -> NSImage? {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", "-s", tempURL.path]  // -i interactive, -s selection

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            return nil
        }

        guard FileManager.default.fileExists(atPath: tempURL.path) else {
            return nil
        }

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        return NSImage(contentsOf: tempURL)
    }

    /// Check if screen capture permission is granted
    private func checkScreenCapturePermission() async throws -> Bool {
        if #available(macOS 14.0, *) {
            do {
                // Try to get shareable content - this will prompt for permission if needed
                _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                return true
            } catch {
                return false
            }
        }
        return true
    }

    /// Request screen capture permission
    @MainActor
    func requestPermission() {
        // Open System Preferences to Screen Recording
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }
}
