import Foundation

/// Service for interacting with Ollama CLI to fetch available models
final class OllamaService {

    enum OllamaError: LocalizedError {
        case notInstalled
        case notRunning
        case parseError
        case commandFailed(String)

        var errorDescription: String? {
            switch self {
            case .notInstalled:
                return "Ollama is not installed"
            case .notRunning:
                return "Ollama is not running"
            case .parseError:
                return "Failed to parse model list"
            case .commandFailed(let message):
                return "Command failed: \(message)"
            }
        }
    }

    /// Fetch available models from Ollama using `ollama ls`
    /// - Returns: Array of model names
    static func fetchAvailableModels() async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let pipe = Pipe()
            let errorPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["ollama", "ls"]
            process.standardOutput = pipe
            process.standardError = errorPipe

            do {
                try process.run()
                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                if process.terminationStatus != 0 {
                    let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
                    if errorOutput.contains("not found") || errorOutput.contains("command not found") {
                        continuation.resume(throwing: OllamaError.notInstalled)
                    } else if errorOutput.contains("refused") || errorOutput.contains("not running") {
                        continuation.resume(throwing: OllamaError.notRunning)
                    } else {
                        continuation.resume(throwing: OllamaError.commandFailed(errorOutput))
                    }
                    return
                }

                guard let output = String(data: data, encoding: .utf8) else {
                    continuation.resume(throwing: OllamaError.parseError)
                    return
                }

                let models = parseModelList(output)
                continuation.resume(returning: models)

            } catch {
                continuation.resume(throwing: OllamaError.notInstalled)
            }
        }
    }

    /// Parse the tabular output from `ollama ls`
    /// Example output:
    /// NAME                    ID              SIZE      MODIFIED
    /// ministral-3:14b         4760c35aeb9d    9.1 GB    2 days ago
    private static func parseModelList(_ output: String) -> [String] {
        let lines = output.components(separatedBy: .newlines)
        var models: [String] = []

        for (index, line) in lines.enumerated() {
            // Skip header line and empty lines
            if index == 0 || line.trimmingCharacters(in: .whitespaces).isEmpty {
                continue
            }

            // The model name is the first column (before whitespace)
            let components = line.split(separator: " ", omittingEmptySubsequences: true)
            if let modelName = components.first {
                models.append(String(modelName))
            }
        }

        return models
    }
}
