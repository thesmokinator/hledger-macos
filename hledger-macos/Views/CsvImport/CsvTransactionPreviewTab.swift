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
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

                Divider()

                // Transaction list
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(previewTransactions.indices, id: \.self) { index in
                            transactionRow(index: index)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func transactionRow(index: Int) -> some View {
        let txn = previewTransactions[index]
        HStack(spacing: 8) {
            Toggle("", isOn: $previewTransactions[index].isSelected)
                .labelsHidden()
                .frame(width: 20)

            Text(txn.date)
                .font(.callout.monospaced())
                .frame(width: 90, alignment: .leading)

            Text(txn.description)
                .font(.callout)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(txn.amount)
                .font(.callout.monospaced())
                .frame(width: 110, alignment: .trailing)

            Text(txn.account2.isEmpty ? txn.account1 : txn.account2)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 160, alignment: .leading)

            if txn.isDuplicate {
                Text("duplicate")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .frame(width: 55)
            } else {
                Spacer()
                    .frame(width: 55)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(txn.isDuplicate ? Color.orange.opacity(0.06) : Color.clear)
    }
}
