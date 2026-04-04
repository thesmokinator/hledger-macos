/// Protocol abstracting the AI model provider for inference.
/// Allows swapping Apple Foundation Models with MLX or other backends.

import Foundation

/// A provider that generates text responses from a prompt.
protocol AIModelProvider: Sendable {
    /// Whether the provider is available on this system.
    static var isAvailable: Bool { get }

    /// Display name for Settings UI.
    static var displayName: String { get }

    /// Generate a streaming response for the given conversation.
    /// The backend is provided so the provider can create tools for tool calling.
    func generate(systemPrompt: String, messages: [ChatMessage], backend: any AccountingBackend) -> AsyncThrowingStream<String, Error>
}

/// Errors from AI model operations.
enum AIModelError: LocalizedError {
    case notAvailable
    case generationFailed(String)
    case sessionCreationFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "AI model is not available on this device."
        case .generationFailed(let msg):
            return "Generation failed: \(msg)"
        case .sessionCreationFailed(let msg):
            return "Could not create AI session: \(msg)"
        }
    }
}
