import AppKit
import Vision

/// OCR provider using Apple's Vision framework (free, local)
final class VisionOCRProvider: OCRProvider {
    /// Recognize text from an image using Vision framework
    /// - Parameter image: The image to process
    /// - Returns: The recognized text
    func recognizeText(from image: NSImage) async throws -> String {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw AppError.ocrFailed("Failed to convert image")
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: AppError.ocrFailed(error.localizedDescription))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }

                let recognizedStrings = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }

                let text = recognizedStrings.joined(separator: "\n")
                continuation.resume(returning: text)
            }

            // Configure for best accuracy
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            // Support multiple languages
            request.recognitionLanguages = ["en-US", "fr-FR", "de-DE", "es-ES", "it-IT"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: AppError.ocrFailed(error.localizedDescription))
            }
        }
    }
}
