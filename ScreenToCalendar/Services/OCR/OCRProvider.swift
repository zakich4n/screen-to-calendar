import AppKit

/// Protocol for OCR providers
protocol OCRProvider {
    /// Recognize text from an image
    /// - Parameter image: The image to process
    /// - Returns: The recognized text
    func recognizeText(from image: NSImage) async throws -> String
}
