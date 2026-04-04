/// Main AI assistant service — orchestrates chat, context building, and model inference.

import SwiftUI

@Observable
@MainActor
final class AIAssistant {
    // MARK: - State

    var messages: [ChatMessage] = []
    var isGenerating = false
    var errorMessage: String?
    var isAvailable: Bool { AppleFoundationModelProvider.isAvailable }

    // MARK: - Private

    private let provider: any AIModelProvider = AppleFoundationModelProvider()
    private var generationTask: Task<Void, Never>?

    // MARK: - Actions

    /// Send a user message and stream the AI response.
    func send(_ text: String, appState: AppState) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Add user message
        messages.append(ChatMessage(role: .user, content: trimmed))

        // Add placeholder for assistant response
        let assistantMessage = ChatMessage(role: .assistant, content: "", isStreaming: true)
        messages.append(assistantMessage)
        let assistantIndex = messages.count - 1

        isGenerating = true
        errorMessage = nil

        generationTask = Task {
            do {
                let systemPrompt = JournalContextBuilder.buildSystemPrompt(from: appState)
                let conversationMessages = messages.filter { $0.role != .system && !$0.isStreaming }
                    + [ChatMessage(role: .user, content: trimmed)]

                let stream = provider.generate(systemPrompt: systemPrompt, messages: conversationMessages)

                var lastText = ""
                for try await text in stream {
                    if Task.isCancelled { break }
                    // Apple FM streams cumulative text, so replace rather than append
                    lastText = text
                    messages[assistantIndex].content = lastText
                }

                messages[assistantIndex].isStreaming = false
                if messages[assistantIndex].content.isEmpty {
                    messages[assistantIndex].content = "I couldn't generate a response. Please try again."
                }
            } catch {
                messages[assistantIndex].isStreaming = false
                if messages[assistantIndex].content.isEmpty {
                    messages[assistantIndex].content = "An error occurred."
                }
                errorMessage = error.localizedDescription
            }

            isGenerating = false
        }
    }

    /// Stop the current generation.
    func stop() {
        generationTask?.cancel()
        generationTask = nil
        isGenerating = false

        // Mark any streaming message as done
        if let index = messages.lastIndex(where: { $0.isStreaming }) {
            messages[index].isStreaming = false
            if messages[index].content.isEmpty {
                messages[index].content = "Generation stopped."
            }
        }
    }

    /// Clear conversation history.
    func clearChat() {
        stop()
        messages.removeAll()
        errorMessage = nil
    }
}
