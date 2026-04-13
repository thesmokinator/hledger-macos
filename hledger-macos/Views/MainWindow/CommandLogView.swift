/// Debug panel showing all hledger commands executed during this session.

import SwiftUI
import UniformTypeIdentifiers

struct CommandLogView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedEntry: CommandLogEntry?
    @State private var filter: LogFilter = .all
    private let log = CommandLog.shared

    private enum LogFilter: String, CaseIterable {
        case all = "All"
        case errors = "Errors"
        case success = "Success"
    }

    private var filteredEntries: [CommandLogEntry] {
        switch filter {
        case .all: return log.entries
        case .errors: return log.entries.filter(\.isError)
        case .success: return log.entries.filter { !$0.isError }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                HStack {
                    Text("Command Log")
                        .font(.headline)
                    Spacer()
                    Button("Export") { exportLog() }
                        .controlSize(.small)
                    Button("Clear") { log.clear() }
                        .controlSize(.small)
                }

                HStack(spacing: 12) {
                    ForEach(LogFilter.allCases, id: \.self) { f in
                        Button {
                            filter = f
                        } label: {
                            Text(filterLabel(f))
                                .font(.caption)
                                .foregroundStyle(filter == f ? .primary : .secondary)
                        }
                        .buttonStyle(.borderless)
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)

            Divider()

            if filteredEntries.isEmpty {
                Spacer()
                Text(filter == .all ? "No commands executed yet." : "No \(filter.rawValue.lowercased()) to show.")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                HSplitView {
                    // Command list
                    List(filteredEntries.reversed(), selection: $selectedEntry) { entry in
                        HStack(spacing: 8) {
                            Image(systemName: entry.isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                                .foregroundStyle(entry.isError ? Theme.Status.critical : Theme.Status.good)
                                .font(.caption)

                            Text(entry.timestampFormatted)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)

                            Text(entry.command)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .tag(entry)
                        .padding(.vertical, Theme.Spacing.xxs)
                    }
                    .listStyle(.inset)
                    .frame(minWidth: 400)

                    // Detail panel
                    if let entry = selectedEntry {
                        entryDetail(entry)
                            .frame(minWidth: 300)
                    } else {
                        VStack {
                            Spacer()
                            Text("Select a command to view details")
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .frame(minWidth: 300)
                    }
                }
            }

            Divider()

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.smPlus)
        }
        .frame(width: 900, height: 500)
    }

    private func filterLabel(_ f: LogFilter) -> String {
        switch f {
        case .all: return "All (\(log.entries.count))"
        case .errors: return "Errors (\(log.errorCount))"
        case .success: return "Success (\(log.entries.count - log.errorCount))"
        }
    }

    // MARK: - Export

    private func exportLog() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.log]
        panel.nameFieldStringValue = "hledger-commands.log"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        var lines: [String] = []
        for entry in log.entries {
            lines.append("[\(entry.timestampFormatted)] [exit:\(entry.exitCode)] \(entry.command)")
            if !entry.stderr.isEmpty {
                lines.append("  STDERR: \(entry.stderr)")
            }
        }

        try? lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Detail

    private func entryDetail(_ entry: CommandLogEntry) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                detailSection("Command", entry.command)

                HStack(spacing: 16) {
                    detailLabel("Exit Code", "\(entry.exitCode)", color: entry.isError ? Theme.Status.critical : Theme.Status.good)
                    detailLabel("Time", entry.timestampFormatted, color: .secondary)
                }

                if !entry.stderr.isEmpty {
                    detailSection("stderr", entry.stderr, color: Theme.Status.critical)
                }

                if !entry.stdout.isEmpty {
                    detailSection("stdout", String(entry.stdout.prefix(2000)))
                }
            }
            .padding(Theme.Spacing.lg)
        }
    }

    private func detailSection(_ title: String, _ content: String, color: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(content)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(color)
                .textSelection(.enabled)
        }
    }

    private func detailLabel(_ title: String, _ value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(color)
        }
    }
}
