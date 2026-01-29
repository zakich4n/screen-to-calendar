# Screen to Calendar

A macOS menu bar app that extracts event details from text and creates calendar events using local LLMs.

> **Work in Progress**
> This project is under active development. Currently:
> - **Clipboard to Event**: Working and tested
> - **Screenshot to Event**: Not fully tested yet, may be unstable

## Features

- Lives in your menu bar for quick access
- Extracts event details (title, date, time, location) from copied text
- Uses local LLMs (Ollama) for privacy - no data sent to external servers
- Supports Apple Vision for OCR
- Creates events directly in Apple Calendar
- "Open in Calendar" button to verify created events

## Requirements

- macOS 14.0+
- [Ollama](https://ollama.ai/) installed locally (for LLM processing)

## Setup

1. Clone the repo
2. Open `ScreenToCalendar.xcodeproj` in Xcode
3. Select your team in Signing & Capabilities
4. Build and run
5. Configure Ollama host and model in Settings

## Usage

1. Copy text containing event details to your clipboard
2. Click the menu bar icon
3. Select "From Clipboard Text"
4. Review and edit the parsed event
5. Click "Save Event" or "Open in Calendar"

## License

MIT
