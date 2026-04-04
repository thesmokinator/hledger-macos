/// A single chat message bubble in the AI conversation.

import SwiftUI

struct AIChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            if message.role == .user { Spacer(minLength: 60) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: Theme.Spacing.xs) {
                Text(message.content.isEmpty && message.isStreaming ? " " : message.content)
                    .textSelection(.enabled)
                    .font(.body)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.md)
                            .fill(message.role == .user ? AnyShapeStyle(.tint.opacity(0.15)) : AnyShapeStyle(.quaternary.opacity(0.5)))
                    )
                    .overlay {
                        if message.isStreaming && message.content.isEmpty {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }

                if message.isStreaming && !message.content.isEmpty {
                    streamingIndicator
                }
            }

            if message.role == .assistant { Spacer(minLength: 60) }
        }
    }

    private var streamingIndicator: some View {
        HStack(spacing: 3) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(.secondary)
                    .frame(width: 4, height: 4)
                    .opacity(0.6)
            }
        }
        .padding(.leading, Theme.Spacing.md)
    }
}
