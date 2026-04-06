/// Tab 3 of the CSV Import Wizard: parsed transaction preview with duplicate detection.
///
/// Shows transactions parsed by hledger via the rules file, flags duplicates,
/// and lets the user select which transactions to import.

import SwiftUI

struct CsvImportPreviewTab: View {
    @Binding var previewTransactions: [CsvPreviewTransaction]
    let isLoading: Bool
    let errorMessage: String?
    let onImport: () -> Void

    private var selectedCount: Int {
        previewTransactions.filter(\.isSelected).count
    }

    private var duplicateCount: Int {
        previewTransactions.filter(\.isDuplicate).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            transactionList
            footer
        }
        .padding(16)
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 16) {
            Label {
                Text("**\(previewTransactions.count)** transactions parsed")
            } icon: {
                Image(systemName: "doc.text")
                    .foregroundStyle(.blue)
            }

            if duplicateCount > 0 {
                Label {
                    Text("**\(duplicateCount)** duplicates")
                } icon: {
                    Image(systemName: "doc.on.doc")
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            Button("Select All") {
                for i in previewTransactions.indices {
                    previewTransactions[i].isSelected = true
                }
            }
            .buttonStyle(.plain)
            .font(.callout)

            Button("Deselect Duplicates") {
                for i in previewTransactions.indices where previewTransactions[i].isDuplicate {
                    previewTransactions[i].isSelected = false
                }
            }
            .buttonStyle(.plain)
            .font(.callout)
            .disabled(duplicateCount == 0)
        }
        .font(.callout)
    }

    // MARK: - Transaction List

    @ViewBuilder
    private var transactionList: some View {
        if isLoading {
            VStack {
                Spacer()
                ProgressView("Parsing CSV with hledger...")
                Spacer()
            }
            .frame(maxWidth: .infinity, minHeight: 200)
        } else if let error = errorMessage {
            VStack(spacing: 8) {
                Spacer()
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.callout)
                Text("Check the Rules Editor tab and verify your column mappings and settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, minHeight: 200)
        } else if previewTransactions.isEmpty {
            VStack {
                Spacer()
                ContentUnavailableView(
                    "No Transactions",
                    systemImage: "tray",
                    description: Text("No transactions were parsed. Check your rules configuration.")
                )
                Spacer()
            }
            .frame(maxWidth: .infinity, minHeight: 200)
        } else {
            ScrollView {
                // Column headers
                HStack(spacing: 0) {
                    Text("")
                        .frame(width: 30)
                    Text("Date")
                        .frame(width: 100, alignment: .leading)
                    Text("Description")
                        .frame(minWidth: 200, alignment: .leading)
                    Text("Amount")
                        .frame(width: 100, alignment: .trailing)
                    Text("Category")
                        .frame(width: 180, alignment: .leading)
                        .padding(.leading, 12)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)

                Divider()

                ForEach(previewTransactions.indices, id: \.self) { index in
                    transactionRow(index: index)
                }
            }
        }
    }

    @ViewBuilder
    private func transactionRow(index: Int) -> some View {
        let txn = previewTransactions[index]
        HStack(spacing: 0) {
            Toggle("", isOn: $previewTransactions[index].isSelected)
                .labelsHidden()
                .frame(width: 30)

            Text(txn.date)
                .font(.callout.monospaced())
                .frame(width: 100, alignment: .leading)

            Text(txn.description)
                .font(.callout)
                .frame(minWidth: 200, alignment: .leading)
                .lineLimit(1)

            Text(txn.amount)
                .font(.callout.monospaced())
                .frame(width: 100, alignment: .trailing)

            Text(txn.account2.isEmpty ? txn.account1 : txn.account2)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 180, alignment: .leading)
                .lineLimit(1)
                .padding(.leading, 12)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(txn.isDuplicate ? Color.orange.opacity(0.08) : Color.clear)
        .overlay(alignment: .trailing) {
            if txn.isDuplicate {
                Text("duplicate")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .padding(.trailing, 4)
            }
        }
    }

    // MARK: - Footer

    @ViewBuilder
    private var footer: some View {
        Divider()

        HStack {
            if selectedCount > 0 {
                Text("\(selectedCount) transaction\(selectedCount == 1 ? "" : "s") will be imported")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Import Selected") {
                onImport()
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedCount == 0 || isLoading)
        }
    }
}
