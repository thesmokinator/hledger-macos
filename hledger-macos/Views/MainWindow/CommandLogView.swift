/// Debug panel showing all hledger commands executed during this session.

import SwiftUI

struct CommandLogView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedEntry: CommandLogEntry?
    private let log = CommandLog.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Command Log")
                    .font(.headline)
                Text("\(log.entries.count) commands")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if log.errorCount > 0 {
                    Text("\(log.errorCount) errors")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Spacer()
                Button("Clear") { log.clear() }
                    .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            if log.entries.isEmpty {
                Spacer()
                Text("No commands executed yet.")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                HSplitView {
                    // Command list
                    List(log.entries.reversed(), selection: $selectedEntry) { entry in
                        HStack(spacing: 8) {
                            Image(systemName: entry.isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                                .foregroundStyle(entry.isError ? .red : .green)
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
                        .padding(.vertical, 2)
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
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 900, height: 500)
    }

    private func entryDetail(_ entry: CommandLogEntry) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                detailSection("Command", entry.command)

                HStack(spacing: 16) {
                    detailLabel("Exit Code", "\(entry.exitCode)", color: entry.isError ? .red : .green)
                    detailLabel("Time", entry.timestampFormatted, color: .secondary)
                }

                if !entry.stderr.isEmpty {
                    detailSection("stderr", entry.stderr, color: .red)
                }

                if !entry.stdout.isEmpty {
                    detailSection("stdout", String(entry.stdout.prefix(2000)))
                }
            }
            .padding(16)
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
