/// Floating button to toggle the AI chat overlay.
/// Positioned at the bottom-left of the main window.

import SwiftUI

struct AIToggleButton: View {
    @Binding var isShowingChat: Bool
    let isAvailable: Bool

    var body: some View {
        Button {
            withAnimation(.spring(duration: 0.3)) {
                isShowingChat.toggle()
            }
        } label: {
            Image(systemName: isShowingChat ? "xmark" : "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isShowingChat ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.white))
                .frame(width: 36, height: 36)
                .background {
                    if isShowingChat {
                        Circle().fill(.quaternary)
                    } else {
                        Circle().fill(.tint)
                    }
                }
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .help(isShowingChat ? "Close AI Assistant" : "AI Assistant")
        .accessibilityLabel(isShowingChat ? "Close AI Assistant" : "Open AI Assistant")
        .opacity(isAvailable ? 1 : 0.5)
        .disabled(!isAvailable)
    }
}
