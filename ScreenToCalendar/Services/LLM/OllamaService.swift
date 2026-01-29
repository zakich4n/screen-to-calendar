import Foundation

/// Service for interacting with Ollama API to fetch available models
final class OllamaService {

    enum OllamaError: LocalizedError {
        case notRunning
        case parseError
        case requestFailed(String)

        var errorDescription: String? {
            switch self {
            case .notRunning:
                return "Ollama is not running. Start it and try again."
            case .parseError:
                return "Failed to parse model list"
            case .requestFailed(let message):
                return message
            }
        }
    }

    /// Fetch available models from Ollama using the HTTP API
    /// - Returns: Array of model names
    static func fetchAvailableModels() async throws -> [String] {
        let host = AppSettings.shared.ollamaHost.trimmingCharacters(in: .init(charactersIn: "/"))
        guard let url = URL(string: "\(host)/api/tags") else {
            throw OllamaError.requestFailed("Invalid Ollama host URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5

        let data: Data
        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)
            data = responseData

            guard let httpResponse = response as? HTTPURLResponse else {
                throw OllamaError.requestFailed("Invalid response")
            }

            guard httpResponse.statusCode == 200 else {
                throw OllamaError.requestFailed("Ollama returned status \(httpResponse.statusCode)")
            }
        } catch let error as OllamaError {
            throw error
        } catch {
            // Connection refused or timeout likely means Ollama isn't running
            throw OllamaError.notRunning
        }

        // Parse the JSON response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["models"] as? [[String: Any]] else {
            throw OllamaError.parseError
        }

        // Extract model names
        return models.compactMap { model -> String? in
            model["name"] as? String
        }
    }
}
