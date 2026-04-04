/// Reusable sort toggle button.
///
/// Two modes:
/// - **Direction toggle** (default): arrow up/down for ASC/DESC on a single criterion.
/// - **Mode toggle**: alternates between two sort modes with custom icons.
///   Use `modeA` / `modeB` parameters.

import SwiftUI

struct SortToggleButton: View {
    @Binding var ascending: Bool
    var ascLabel: String = "Sort ascending"
    var descLabel: String = "Sort descending"
    var modeA: SortMode?
    var modeB: SortMode?

    var body: some View {
        if let a = modeA, let b = modeB {
            // Mode toggle: two predefined sort modes
            Button {
                ascending.toggle()
            } label: {
                Image(systemName: ascending ? a.icon : b.icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help(ascending ? a.label : b.label)
        } else {
            // Direction toggle: ASC/DESC
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
}

/// Describes a sort mode for SortToggleButton.
struct SortMode {
    let icon: String
    let label: String

    static let byAmount = SortMode(icon: "arrow.down", label: "Sorted by amount")
    static let byName = SortMode(icon: "textformat.abc", label: "Sorted by name")
}
