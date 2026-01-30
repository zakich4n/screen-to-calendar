import SwiftUI
import KeyboardShortcuts

enum MenuBarViewState {
    case menu
    case eventForm
}

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settings: AppSettings
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    @State private var viewState: MenuBarViewState = .menu
    @State private var showOnboarding = false

    var body: some View {
        Group {
            switch viewState {
            case .menu:
                menuContent
            case .eventForm:
                eventFormContent
            }
        }
        .onChange(of: appState.showEventForm) { _, show in
            if show {
                viewState = .eventForm
            }
        }
        .onChange(of: appState.currentParsedEvent) { _, event in
            if event == nil {
                viewState = .menu
            }
        }
        .onAppear {
            if !settings.hasShownFirstRunPrompt {
                showOnboarding = true
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView()
                .environmentObject(settings)
        }
    }

    // MARK: - Menu Content

    private var menuContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "calendar.badge.plus")
                    .foregroundStyle(.blue)
                Text("Screen to Calendar")
                    .font(.headline)
            }
            .padding(.bottom, 4)

            Divider()

            // Status
            if appState.isProcessing {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(appState.processingMessage ?? "Processing...")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .padding(.vertical, 4)
            } else if let error = appState.lastError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error.localizedDescription)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .lineLimit(2)
                }
                .padding(.vertical, 4)
            }

            // Main Actions
            VStack(spacing: 8) {
                ActionButton(
                    title: "From Clipboard Text",
                    shortcut: KeyboardShortcuts.getShortcut(for: .captureText),
                    systemImage: "doc.on.clipboard",
                    isDisabled: appState.isProcessing
                ) {
                    Task {
                        await appState.processClipboardText()
                    }
                }

                ActionButton(
                    title: "From Screenshot",
                    shortcut: KeyboardShortcuts.getShortcut(for: .captureScreenshot),
                    systemImage: "camera.viewfinder",
                    isDisabled: appState.isProcessing
                ) {
                    Task {
                        await appState.processScreenshot()
                    }
                }
            }

            Divider()

            // Provider Info
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("LLM: \(settings.selectedLLMProvider.displayName)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("OCR: \(settings.selectedOCRProvider.displayName)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Divider()

            // Bottom Actions
            HStack {
                Button {
                    // Open window first, then activate with delay to ensure window exists
                    openWindow(id: "settings")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        NSApp.activate(ignoringOtherApps: true)
                        // Also bring all windows to front
                        for window in NSApp.windows where window.title == "Settings" {
                            window.makeKeyAndOrderFront(nil)
                        }
                    }
                } label: {
                    Label("Settings...", systemImage: "gear")
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit", systemImage: "power")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            }
        }
        .padding()
        .frame(width: 280)
    }

    // MARK: - Event Form Content

    private var eventFormContent: some View {
        Group {
            if let event = appState.currentParsedEvent {
                EventFormView(
                    event: event,
                    onCancel: {
                        appState.clearCurrentEvent()
                    },
                    onSave: {
                        appState.clearCurrentEvent()
                    }
                )
            }
        }
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let title: String
    let shortcut: KeyboardShortcuts.Shortcut?
    let systemImage: String
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                    .frame(width: 20)
                Text(title)
                Spacer()
                if let shortcut = shortcut {
                    Text(shortcut.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
    }
}

#Preview {
    MenuBarView()
        .environmentObject(AppState.shared)
        .environmentObject(AppSettings.shared)
}
