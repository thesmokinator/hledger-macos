/// Reusable sort toggle button with arrow up/down icon.

import SwiftUI

struct SortToggleButton: View {
    @Binding var ascending: Bool
    var ascLabel: String = "Sort ascending"
    var descLabel: String = "Sort descending"

    var body: some View {
        Button {
            ascending.toggle()
        } label: {
            Image(systemName: ascending ? "arrow.up" : "arrow.down")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
        .help(ascending ? descLabel : ascLabel)
    }
}
