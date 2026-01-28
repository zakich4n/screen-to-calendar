import SwiftUI
import KeyboardShortcuts

@main
struct ScreenToCalendarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared
    @StateObject private var settings = AppSettings.shared

    var body: some Scene {
        // Menu Bar
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
                .environmentObject(settings)
        } label: {
            Label("Screen to Calendar", systemImage: "calendar.badge.plus")
        }
        .menuBarExtraStyle(.window)

        // Settings Window (using Window instead of Settings for LSUIElement compatibility)
        Window("Settings", id: "settings") {
            SettingsView()
                .environmentObject(settings)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        // Event Form Window
        Window("New Event", id: "event-form") {
            if let event = appState.currentParsedEvent {
                EventFormView(event: event)
                    .environmentObject(appState)
                    .environmentObject(settings)
            }
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}
