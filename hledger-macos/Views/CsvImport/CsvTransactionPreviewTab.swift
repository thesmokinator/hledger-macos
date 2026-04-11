/// Tab 3 of the CSV Import Wizard: parsed transaction preview with duplicate detection.
///
/// Shows transactions parsed by hledger via the rules file, flags duplicates,
/// and lets the user select which transactions to import.
/// The Import button is in the parent sheet's bottom bar.

import SwiftUI

struct CsvTransactionPreviewTab: View {
    @Binding var previewTransactions: [CsvPreviewTransaction]
    let isLoading: Bool
    let errorMessage: String?

    private var duplicateCount: Int {
        previewTransactions.filter(\.isDuplicate).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isLoading {
                LoadingOverlay(message: "Parsing CSV with hledger...")
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if previewTransactions.isEmpty {
                VStack {
                    Spacer()
                    ContentUnavailableView(
                        "No Transactions",
                        systemImage: "tray",
                        description: Text("Go to tab 2 to configure rules, then come back here.")
                    )
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Header
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
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.sm)

                Divider()

                // Transaction list — native List for alternating rows and macOS look,
                // matching TransactionsView and AccountsView.
                List {
                    ForEach(previewTransactions.indices, id: \.self) { index in
                        transactionRow(index: index)
                            .listRowBackground(
                                previewTransactions[index].isDuplicate
                                    ? Color.orange.opacity(0.08)
                                    : Color.clear
                            )
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    @ViewBuilder
    private func transactionRow(index: Int) -> some View {
        let txn = previewTransactions[index]
        HStack(spacing: 12) {
            Toggle("", isOn: $previewTransactions[index].isSelected)
                .labelsHidden()
                .frame(width: 18)

            Text(txn.date)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.secondary)

            Text(txn.description)
                .font(.callout)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            if txn.isDuplicate {
                Text("duplicate")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
            }

            Text(txn.account2.isEmpty ? txn.account1 : txn.account2)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.head)
                .frame(width: 180, alignment: .trailing)

            Text(txn.amount)
                .font(.system(.callout, design: .monospaced))
                .frame(width: 110, alignment: .trailing)
        }
        .padding(.vertical, ListMetrics.rowPadding)
    }
}
