/// AI chat overlay — floating panel over the main window.
/// Slides in from the right with translucent material background.

import SwiftUI

struct AIChatOverlay: View {
    @Environment(AppState.self) private var appState
    @Bindable var assistant: AIAssistant
    @Binding var isShowing: Bool
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if let error = assistant.errorMessage {
                errorBanner(error)
            }
            messageList
            Divider()
            inputBar
        }
        .frame(width: 440)
        .frame(maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
        .shadow(color: .black.opacity(0.2), radius: 12, x: -4, y: 0)
        .transition(.move(edge: .trailing).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.2), value: assistant.errorMessage)
        .onAppear { isInputFocused = true }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "sparkles")
                .foregroundStyle(.tint)
            Text("AI Assistant")
                .font(.headline)

            Spacer()

            if !assistant.messages.isEmpty {
                Button {
                    assistant.clearChat()
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear conversation")
            }

            Button {
                withAnimation(.spring(duration: 0.3)) {
                    isShowing = false
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.callout)

            Text(message)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(2)

            Spacer()

            Button("Retry") {
                assistant.retryLast(appState: appState)
            }
            .font(.caption.bold())
            .buttonStyle(.borderless)
            .foregroundStyle(.tint)

            Button {
                assistant.errorMessage = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
        .background(.orange.opacity(0.12))
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if assistant.messages.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: Theme.Spacing.md) {
                        ForEach(assistant.messages.filter { $0.role != .system }) { message in
                            AIChatBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.sm)
                }
            }
            .onChange(of: assistant.messages.count) {
                if let last = assistant.messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: assistant.messages.last?.content) {
                if let last = assistant.messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)

            Text("Ask about your finances")
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                suggestionButton("What are my top expenses this month?")
                suggestionButton("How much did I earn this period?")
                suggestionButton("What is my net worth?")
            }

            Spacer()
        }
        .padding(Theme.Spacing.xl)
    }

    private func suggestionButton(_ text: String) -> some View {
        Button {
            inputText = text
            sendMessage()
        } label: {
            Text(text)
                .font(.callout)
                .foregroundStyle(.tint)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(.tint.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: Theme.Spacing.sm) {
            TextField("Ask something...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .focused($isInputFocused)
                .onSubmit { sendMessage() }

            if assistant.isGenerating {
                Button {
                    assistant.stop()
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .help("Stop generating")
            } else {
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title3)
                        .foregroundStyle(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.tint))
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help("Send message")
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
    }

    // MARK: - Actions

    private func sendMessage() {
        let text = inputText
        inputText = ""
        assistant.send(text, appState: appState)
    }
}
