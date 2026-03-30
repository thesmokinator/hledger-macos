/// hledger for macOS — a native companion for plain text accounting.

import SwiftUI

@main
struct hledger_macosApp: App {
    @State private var appState = AppState()
    @State private var showingShortcuts = false

    var body: some Scene {
        Window("hledger", id: "main") {
            Group {
                if appState.isInitialized {
                    ContentView()
                } else {
                    OnboardingView()
                }
            }
            .environment(appState)
            .task {
                await appState.initialize()
            }
            .sheet(isPresented: $showingShortcuts) {
                ShortcutsView()
            }
        }
        .commands {
            AppCommands(appState: appState, showingShortcuts: $showingShortcuts)
        }

        Settings {
            SettingsView()
                .environment(appState)
        }
    }
}

/// App-level menu commands with keyboard shortcuts.
struct AppCommands: Commands {
    let appState: AppState
    @Binding var showingShortcuts: Bool

    var body: some Commands {
        // Replace "New Window" with "New Transaction"
        CommandGroup(replacing: .newItem) {
            Button("New Transaction") {
                appState.showNewTransaction()
            }
            .keyboardShortcut("n", modifiers: .command)
        }

        CommandGroup(replacing: .saveItem) {
            Button("Reload") {
                Task { await appState.reload() }
            }
            .keyboardShortcut("r", modifiers: .command)
        }

        // Cmd+1..6 to switch sidebar sections
        CommandMenu("Sections") {
            Button("Summary") { appState.selectedSection = .summary }
                .keyboardShortcut("1", modifiers: .command)
            Button("Transactions") { appState.selectedSection = .transactions }
                .keyboardShortcut("2", modifiers: .command)
            Button("Recurring") { appState.selectedSection = .recurring }
                .keyboardShortcut("3", modifiers: .command)
            Button("Budget") { appState.selectedSection = .budget }
                .keyboardShortcut("4", modifiers: .command)
            Button("Reports") { appState.selectedSection = .reports }
                .keyboardShortcut("5", modifiers: .command)
            Button("Accounts") { appState.selectedSection = .accounts }
                .keyboardShortcut("6", modifiers: .command)
        }

        // Help > Keyboard Shortcuts
        CommandGroup(after: .help) {
            Button("Keyboard Shortcuts") {
                showingShortcuts = true
            }
            .keyboardShortcut("/", modifiers: .command)
        }

        SidebarCommands()
    }
}

// MARK: - Keyboard Shortcuts Panel

struct ShortcutsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Text("Keyboard Shortcuts")
                .font(.headline)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    shortcutGroup("Navigation") {
                        shortcutRow("\u{2318}1 \u{2013} \u{2318}6", "Switch section")
                        shortcutRow("\u{2190} / \u{2192}", "Previous / next month")
                        shortcutRow("\u{2318}T", "Go to current month")
                        shortcutRow("\u{2318}R", "Reload data")
                    }

                    shortcutGroup("Transactions") {
                        shortcutRow("\u{2318}N", "New transaction")
                        shortcutRow("\u{2318}E", "Edit selected transaction")
                        shortcutRow("\u{2318}D", "Clone transaction")
                        shortcutRow("\u{232B}", "Delete transaction")
                    }

                    shortcutGroup("General") {
                        shortcutRow("\u{2318},", "Settings")
                        shortcutRow("\u{2318}/", "Show this panel")
                    }
                }
                .padding(20)
            }

            Divider()

            Button("Done") { dismiss() }
                .keyboardShortcut(.defaultAction)
                .padding(12)
        }
        .frame(width: 360, height: 380)
    }

    private func shortcutGroup<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            content()
        }
    }

    private func shortcutRow(_ keys: String, _ description: String) -> some View {
        HStack {
            Text(keys)
                .font(.system(.body, design: .monospaced))
                .frame(width: 120, alignment: .trailing)
                .foregroundStyle(.secondary)

            Text(description)
                .font(.body)
        }
    }
}
