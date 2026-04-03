/// hledger for macOS — a native companion for plain text accounting.

import SwiftUI

@main
struct hledger_macosApp: App {
    @State private var appState = AppState()
    @State private var showingShortcuts = false
    @State private var showingCommandLog = false
    @State private var updateStatus: UpdateStatus?
    @State private var showingUpdateAlert = false

    private func applyAppearance() {
        switch appState.config.appearance {
        case "light":
            NSApp.appearance = NSAppearance(named: .aqua)
        case "dark":
            NSApp.appearance = NSAppearance(named: .darkAqua)
        default:
            NSApp.appearance = nil // system default
        }
    }

    var body: some Scene {
        Window("hledger for Mac", id: "main") {
            Group {
                if appState.isChecking {
                    Color.clear
                } else if appState.isInitialized {
                    ContentView()
                } else {
                    OnboardingView()
                }
            }
            .environment(appState)
            .preferredColorScheme(appState.config.colorScheme)
            .task {
                await appState.initialize()
                applyAppearance()
                // Silent update check at startup
                let status = await UpdateChecker.check()
                if case .updateAvailable = status {
                    updateStatus = status
                    showingUpdateAlert = true
                }
            }
            .onChange(of: appState.config.appearance) {
                applyAppearance()
            }
            .sheet(isPresented: $showingShortcuts) {
                ShortcutsView()
            }
            .sheet(isPresented: $showingCommandLog) {
                CommandLogView()
            }
            .alert("Update Available", isPresented: $showingUpdateAlert) {
                if case .updateAvailable(_, let url, let downloadUrl) = updateStatus {
                    if let downloadUrl {
                        Button("Download") { NSWorkspace.shared.open(URL(string: downloadUrl)!) }
                    }
                    Button("View Release") { NSWorkspace.shared.open(URL(string: url)!) }
                    Button("Later", role: .cancel) {}
                } else if case .upToDate = updateStatus {
                    Button("OK", role: .cancel) {}
                } else {
                    Button("OK", role: .cancel) {}
                }
            } message: {
                switch updateStatus {
                case .updateAvailable(let version, _, _):
                    Text("Version \(version) is available. You're running \(UpdateChecker.currentVersion).")
                case .upToDate:
                    Text("You're running the latest version (\(UpdateChecker.currentVersion)).")
                case .error(let msg):
                    Text("Could not check for updates: \(msg)")
                case nil:
                    Text("")
                }
            }
        }
        .commands {
            AppCommands(appState: appState, showingShortcuts: $showingShortcuts, showingCommandLog: $showingCommandLog, checkForUpdate: {
                Task {
                    updateStatus = await UpdateChecker.check()
                    showingUpdateAlert = true
                }
            })
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
    @Binding var showingCommandLog: Bool
    var checkForUpdate: () -> Void

    var body: some Commands {
        // Cmd+N: context-aware "New" action
        CommandGroup(replacing: .newItem) {
            Button("New...") {
                appState.triggerNew()
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

        // App menu > Check for Updates
        CommandGroup(after: .appInfo) {
            Button("Check for Updates...") {
                checkForUpdate()
            }
        }

        // Help > Keyboard Shortcuts & Command Log
        CommandGroup(after: .help) {
            Button("Keyboard Shortcuts") {
                showingShortcuts = true
            }
            .keyboardShortcut("/", modifiers: .command)

            Button("Command Log") {
                showingCommandLog = true
            }
            .keyboardShortcut("l", modifiers: [.command, .option])
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
                        shortcutRow("\u{2318}E", "Edit selected")
                        shortcutRow("\u{2318}D", "Clone selected")
                        shortcutRow("\u{2318}\u{232B}", "Delete selected")
                        shortcutRow("Tab", "Select first transaction")
                        shortcutRow("\u{2191} / \u{2193}", "Navigate list")
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
