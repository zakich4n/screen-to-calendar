import SwiftUI
import EventKit

struct EventFormView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var isAllDay: Bool
    @State private var location: String
    @State private var notes: String
    @State private var selectedCalendarIdentifier: String?

    @State private var availableCalendars: [EKCalendar] = []
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showSourceText = false

    private let originalEvent: ParsedEvent
    private let onCancel: (() -> Void)?
    private let onSave: (() -> Void)?

    init(event: ParsedEvent, onCancel: (() -> Void)? = nil, onSave: (() -> Void)? = nil) {
        self.originalEvent = event
        self.onCancel = onCancel
        self.onSave = onSave
        _title = State(initialValue: event.title)
        _startDate = State(initialValue: event.startDate)
        _endDate = State(initialValue: event.effectiveEndDate)
        _isAllDay = State(initialValue: event.isAllDay)
        _location = State(initialValue: event.location ?? "")
        _notes = State(initialValue: event.notes ?? "")
        _selectedCalendarIdentifier = State(initialValue: event.calendarIdentifier)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "calendar.badge.plus")
                    .foregroundStyle(.blue)
                    .font(.title2)
                Text("New Event")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Form
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Title
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Title")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Event title", text: $title)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Date and Time
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("All-day event", isOn: $isAllDay)

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Start")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if isAllDay {
                                    DatePicker("", selection: $startDate, displayedComponents: .date)
                                        .labelsHidden()
                                } else {
                                    DatePicker("", selection: $startDate)
                                        .labelsHidden()
                                }
                            }

                            if !isAllDay {
                                Spacer()
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("End")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    DatePicker("", selection: $endDate)
                                        .labelsHidden()
                                }
                            }
                        }
                    }

                    // Location
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Location")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Add location", text: $location)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Calendar Picker
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Calendar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("", selection: $selectedCalendarIdentifier) {
                            ForEach(availableCalendars, id: \.calendarIdentifier) { calendar in
                                HStack {
                                    Circle()
                                        .fill(Color(calendar.color))
                                        .frame(width: 10, height: 10)
                                    Text(calendar.title)
                                }
                                .tag(calendar.calendarIdentifier as String?)
                            }
                        }
                        .labelsHidden()
                    }

                    // Notes
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $notes)
                            .frame(minHeight: 60)
                            .font(.body)
                            .scrollContentBackground(.hidden)
                            .padding(4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(NSColor.textBackgroundColor))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                            )
                    }

                    // Source text toggle
                    if let sourceText = originalEvent.sourceText, !sourceText.isEmpty {
                        DisclosureGroup("Source Text", isExpanded: $showSourceText) {
                            Text(sourceText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(NSColor.controlBackgroundColor))
                                )
                        }
                    }

                    // Error message
                    if let error = saveError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(error)
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                    }
                }
                .padding()
            }

            Divider()

            // Footer buttons
            HStack {
                Button("Cancel") {
                    if let onCancel = onCancel {
                        onCancel()
                    } else {
                        appState.clearCurrentEvent()
                        dismiss()
                    }
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("Save Event") {
                    saveEvent()
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.isEmpty || isSaving)
                .keyboardShortcut(.return)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 380, height: 520)
        .onAppear {
            loadCalendars()
        }
    }

    private func loadCalendars() {
        let eventStore = EKEventStore()

        // Request access if needed
        Task {
            do {
                let granted = try await eventStore.requestFullAccessToEvents()
                if granted {
                    await MainActor.run {
                        availableCalendars = eventStore.calendars(for: .event)
                            .filter { $0.allowsContentModifications }
                            .sorted { $0.title < $1.title }

                        // Set default calendar
                        if selectedCalendarIdentifier == nil {
                            selectedCalendarIdentifier = settings.defaultCalendarIdentifier
                                ?? eventStore.defaultCalendarForNewEvents?.calendarIdentifier
                                ?? availableCalendars.first?.calendarIdentifier
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    saveError = "Calendar access denied"
                }
            }
        }
    }

    private func saveEvent() {
        isSaving = true
        saveError = nil

        let event = ParsedEvent(
            id: originalEvent.id,
            title: title,
            startDate: startDate,
            endDate: isAllDay ? nil : endDate,
            isAllDay: isAllDay,
            location: location.isEmpty ? nil : location,
            notes: notes.isEmpty ? nil : notes,
            calendarIdentifier: selectedCalendarIdentifier,
            sourceText: originalEvent.sourceText
        )

        Task {
            do {
                try await appState.saveEvent(event)
                await MainActor.run {
                    isSaving = false
                    if settings.closeFormAfterSave {
                        if let onSave = onSave {
                            onSave()
                        } else {
                            appState.clearCurrentEvent()
                            dismiss()
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    saveError = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    EventFormView(event: ParsedEvent(
        title: "Meeting with John",
        startDate: Date(),
        endDate: Date().addingTimeInterval(3600),
        location: "Coffee Shop",
        sourceText: "Meeting with John tomorrow at 2pm at the coffee shop"
    ))
    .environmentObject(AppState.shared)
    .environmentObject(AppSettings.shared)
}
