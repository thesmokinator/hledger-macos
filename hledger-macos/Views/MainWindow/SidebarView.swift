/// Sidebar navigation with section list and shortcut hints.

import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState
        List(NavigationSection.allCases, selection: $state.selectedSection) { section in
            HStack {
                Label(section.label, systemImage: section.systemImage)
                Spacer()
                Text("\u{2318}\(section.shortcutNumber)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            .tag(section)
        }
        .listStyle(.sidebar)
        .navigationTitle("hledger")
    }
}
