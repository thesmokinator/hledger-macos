/// A single chat message bubble in the AI conversation.

import SwiftUI

struct AIChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            if message.role == .user { Spacer(minLength: 60) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: Theme.Spacing.xs) {
                Text(markdownContent)
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

    /// Render message content as markdown when possible, falling back to plain text.
    private var markdownContent: AttributedString {
        let raw = message.content.isEmpty && message.isStreaming ? " " : message.content
        if let attributed = try? AttributedString(markdown: raw, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            return attributed
        }
        return AttributedString(raw)
    }

    private var streamingIndicator: some View {
        HStack(spacing: 3) {
            ForEach(0..<3) { i in
                AnimatedDot(delay: Double(i) * 0.2)
            }
        }
        .padding(.leading, Theme.Spacing.md)
        .accessibilityHidden(true)
    }
}

private struct AnimatedDot: View {
    let delay: Double
    @State private var scale: CGFloat = 0.6

    var body: some View {
        Circle()
            .fill(.secondary)
            .frame(width: 4, height: 4)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 0.5)
                    .repeatForever(autoreverses: true)
                    .delay(delay)
                ) {
                    scale = 1.0
                }
            }
    }
}
