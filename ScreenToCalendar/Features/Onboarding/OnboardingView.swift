import EventKit
import ScreenCaptureKit
import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) var dismiss

    @State private var calendarStatus: PermissionStatus = .unknown
    @State private var screenRecordingStatus: PermissionStatus = .unknown

    private let screenCaptureService = ScreenCaptureService()

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)

                Text("Welcome to Screen to Calendar")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Grant permissions to get started")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)

            Divider()

            // Permission rows
            VStack(spacing: 16) {
                PermissionRow(
                    title: "Calendar Access",
                    description: "Required to create events",
                    systemImage: "calendar",
                    status: calendarStatus
                ) {
                    requestCalendarAccess()
                }

                PermissionRow(
                    title: "Screen Recording",
                    description: "Required for screenshot capture",
                    systemImage: "camera.viewfinder",
                    status: screenRecordingStatus
                ) {
                    screenCaptureService.requestPermission()
                }
            }

            Divider()

            // Launch at login toggle
            Toggle(isOn: $settings.launchAtStartup) {
                HStack(spacing: 12) {
                    Image(systemName: "power")
                        .font(.title3)
                        .foregroundStyle(.green)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Launch at Login")
                            .font(.body)
                        Text("Start automatically when you log in")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .toggleStyle(.switch)
            .padding(.horizontal, 4)

            Spacer()

            // Done button
            Button {
                settings.hasShownFirstRunPrompt = true
                dismiss()
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(24)
        .frame(width: 380, height: 480)
        .onAppear {
            checkPermissions()
        }
    }

    private func checkPermissions() {
        // Check calendar status
        let calendarAuthStatus = EKEventStore.authorizationStatus(for: .event)
        switch calendarAuthStatus {
        case .fullAccess:
            calendarStatus = .granted
        case .denied, .restricted:
            calendarStatus = .denied
        case .notDetermined, .writeOnly:
            calendarStatus = .notRequested
        @unknown default:
            calendarStatus = .unknown
        }

        // Check screen recording status
        Task {
            await checkScreenRecordingPermission()
        }
    }

    @MainActor
    private func checkScreenRecordingPermission() async {
        if #available(macOS 14.0, *) {
            do {
                _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                screenRecordingStatus = .granted
            } catch {
                // Could be denied or not yet requested
                screenRecordingStatus = .notRequested
            }
        } else {
            // For older macOS, use CGPreflightScreenCaptureAccess
            if CGPreflightScreenCaptureAccess() {
                screenRecordingStatus = .granted
            } else {
                screenRecordingStatus = .notRequested
            }
        }
    }

    private func requestCalendarAccess() {
        Task {
            let eventStore = EKEventStore()
            do {
                let granted = try await eventStore.requestFullAccessToEvents()
                await MainActor.run {
                    calendarStatus = granted ? .granted : .denied
                }
            } catch {
                await MainActor.run {
                    calendarStatus = .denied
                }
            }
        }
    }
}

// MARK: - Permission Status

enum PermissionStatus {
    case unknown
    case notRequested
    case granted
    case denied
}

// MARK: - Permission Row

struct PermissionRow: View {
    let title: String
    let description: String
    let systemImage: String
    let status: PermissionStatus
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            statusView
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var statusView: some View {
        switch status {
        case .granted:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Granted")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .denied:
            Button("Open Settings") {
                action()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        case .notRequested, .unknown:
            Button("Grant Access") {
                action()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppSettings.shared)
}
