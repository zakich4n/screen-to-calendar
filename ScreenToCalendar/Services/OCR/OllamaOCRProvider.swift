import AppKit
import Foundation

/// OCR provider using Ollama with a vision model (e.g., LLaVA)
final class OllamaOCRProvider: OCRProvider {
    private let settings = AppSettings.shared

    /// Recognize text from an image using Ollama vision model
    /// - Parameter image: The image to process
    /// - Returns: The recognized text
    func recognizeText(from image: NSImage) async throws -> String {
        // Convert image to base64
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            throw AppError.ocrFailed("Failed to convert image to PNG")
        }

        let base64Image = pngData.base64EncodedString()

        // Build request
        let host = settings.ollamaHost.trimmingCharacters(in: .init(charactersIn: "/"))
        guard let url = URL(string: "\(host)/api/generate") else {
            throw AppError.ocrFailed("Invalid Ollama host URL")
        }

        let requestBody: [String: Any] = [
            "model": settings.ollamaVisionModel,
            "prompt": "Extract and return only the text visible in this image. Return the raw text without any commentary or formatting.",
            "images": [base64Image],
            "stream": false
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 120  // Vision models can be slow

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.ocrFailed("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AppError.ocrFailed("Ollama error (\(httpResponse.statusCode)): \(errorMessage)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = json["response"] as? String else {
            throw AppError.ocrFailed("Failed to parse Ollama response")
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
