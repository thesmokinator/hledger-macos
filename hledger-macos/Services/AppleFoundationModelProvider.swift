/// Apple Foundation Models implementation of AIModelProvider.
/// Uses the on-device Apple Intelligence model available on macOS 26+.

import Foundation
import FoundationModels

struct AppleFoundationModelProvider: AIModelProvider {
    static var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    static var displayName: String { "Apple Intelligence" }

    func generate(systemPrompt: String, messages: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        let (stream, continuation) = AsyncThrowingStream<String, Error>.makeStream()

        let task = Task {
            do {
                let session = LanguageModelSession(
                    instructions: systemPrompt
                )

                // Feed conversation history (skip system messages, already in instructions)
                for message in messages.dropLast() {
                    switch message.role {
                    case .user:
                        _ = try await session.respond(to: message.content)
                    case .assistant, .system:
                        continue
                    }
                }

                // Stream the response for the last user message
                guard let lastMessage = messages.last, lastMessage.role == .user else {
                    continuation.finish()
                    return
                }

                let stream = session.streamResponse(to: lastMessage.content)

                for try await partial in stream {
                    if Task.isCancelled { break }
                    continuation.yield(partial.content)
                }

                continuation.finish()
            } catch {
                continuation.finish(throwing: AIModelError.generationFailed(error.localizedDescription))
            }
        }

        continuation.onTermination = { _ in
            task.cancel()
        }

        return stream
    }
}
