/// Main AI assistant service — orchestrates chat, tool calling, and model inference.

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
        guard let backend = appState.activeBackend else {
            errorMessage = String(localized: "No accounting backend available.")
            return
        }

        // Add user message
        messages.append(ChatMessage(role: .user, content: trimmed))

        // Add placeholder for assistant response
        let assistantMessage = ChatMessage(role: .assistant, content: "", isStreaming: true)
        messages.append(assistantMessage)
        let assistantIndex = messages.count - 1

        isGenerating = true
        errorMessage = nil

        let systemPrompt = JournalContextBuilder.buildSystemPrompt(from: appState)
        let conversationMessages = messages.filter { $0.role != .system && !$0.isStreaming }
            + [ChatMessage(role: .user, content: trimmed)]

        let log = CommandLog.shared

        generationTask = Task {
            log.log(command: "[AI] Query: \(trimmed)", exitCode: 0, stdout: "", stderr: "")

            do {
                let stream = provider.generate(
                    systemPrompt: systemPrompt,
                    messages: conversationMessages,
                    backend: backend
                )

                var lastText = ""
                for try await text in stream {
                    if Task.isCancelled { break }
                    lastText = text
                    messages[assistantIndex].content = lastText
                }

                messages[assistantIndex].isStreaming = false
                if messages[assistantIndex].content.isEmpty {
                    messages[assistantIndex].content = "I couldn't generate a response. Please try again."
                    log.log(command: "[AI] Response", exitCode: 1, stdout: "", stderr: "Empty response")
                } else {
                    log.log(command: "[AI] Response", exitCode: 0, stdout: lastText, stderr: "")
                }
            } catch {
                messages[assistantIndex].isStreaming = false
                let errorDesc = error.localizedDescription
                if messages[assistantIndex].content.isEmpty {
                    messages[assistantIndex].content = "Sorry, something went wrong: \(errorDesc)"
                }
                errorMessage = errorDesc
                log.log(command: "[AI] Error", exitCode: 1, stdout: "", stderr: errorDesc)
            }

            isGenerating = false
        }
    }

    /// Stop the current generation.
    func stop() {
        generationTask?.cancel()
        generationTask = nil
        isGenerating = false

        if let index = messages.lastIndex(where: { $0.isStreaming }) {
            messages[index].isStreaming = false
            if messages[index].content.isEmpty {
                messages[index].content = "Generation stopped."
            }
        }
    }

    /// Retry the last user message after an error.
    func retryLast(appState: AppState) {
        // Drop the failed assistant bubble
        if let i = messages.lastIndex(where: { $0.role == .assistant }) {
            messages.remove(at: i)
        }
        // Grab and drop the last user message (send() will re-add it)
        guard let lastUserIndex = messages.lastIndex(where: { $0.role == .user }) else { return }
        let lastUserContent = messages[lastUserIndex].content
        messages.remove(at: lastUserIndex)
        errorMessage = nil
        send(lastUserContent, appState: appState)
    }

    /// Clear conversation history.
    func clearChat() {
        stop()
        messages.removeAll()
        errorMessage = nil
    }
}
