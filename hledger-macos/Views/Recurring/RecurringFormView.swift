/// Form for adding or editing a recurring transaction rule.

import SwiftUI

struct RecurringFormView: View {
    let editingRule: RecurringRule?
    let knownAccounts: [String]
    let onSave: (RecurringRule) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var periodExpr = "monthly"
    @State private var description = ""
    @State private var startDate = ""
    @State private var endDate = ""
    @State private var postingRows: [PostingRow] = [PostingRow(), PostingRow()]

    private var isEditing: Bool { editingRule != nil }
    private var title: String { isEditing ? "Edit Recurring Rule" : "New Recurring Rule" }

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.accentColor)
                .padding(.top, 20)
                .padding(.bottom, 16)

            Form {
                Section("Schedule") {
                    Picker("Period", selection: $periodExpr) {
                        ForEach(RecurringManager.supportedPeriods, id: \.self) { period in
                            Text(period.capitalized).tag(period)
                        }
                    }

                    TextField("Start date (YYYY-MM-DD)", text: $startDate)
                    TextField("End date (optional)", text: $endDate)
                }

                Section("Transaction") {
                    TextField("Description", text: $description)
                }

                Section("Postings") {
                    ForEach(Array(postingRows.enumerated()), id: \.element.id) { index, _ in
                        HStack(spacing: 8) {
                            Text("#\(index + 1):")
                                .font(.callout.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 30, alignment: .trailing)

                            AutocompleteField(
                                placeholder: "e.g. expenses:food",
                                text: $postingRows[index].account,
                                suggestions: knownAccounts
                            )

                            TextField("0.00", text: $postingRows[index].amount)
                                .frame(width: 100)

                            if postingRows.count > 2 {
                                Button {
                                    postingRows.remove(at: index)
                                } label: {
                                    Image(systemName: "minus.circle").foregroundStyle(.red)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }

                    Button {
                        postingRows.append(PostingRow())
                    } label: {
                        Label("Add Posting", systemImage: "plus")
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(description.isEmpty || startDate.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .frame(width: 500, height: 520)
        .onAppear { prefill() }
    }

    private func prefill() {
        if let rule = editingRule {
            periodExpr = rule.periodExpr
            description = rule.description
            startDate = rule.startDate ?? ""
            endDate = rule.endDate ?? ""
            postingRows = rule.postings.map {
                PostingRow(
                    account: $0.account,
                    amount: $0.amounts.first.map { $0.formatted() } ?? ""
                )
            }
        }
        while postingRows.count < 2 { postingRows.append(PostingRow()) }

        if startDate.isEmpty {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            startDate = f.string(from: Date())
        }
    }

    private func save() {
        var postings: [Posting] = []
        for row in postingRows where !row.account.isEmpty {
            if row.amount.isEmpty {
                postings.append(Posting(account: row.account))
            } else {
                let (qty, commodity) = AmountParser.parse(row.amount)
                postings.append(Posting(
                    account: row.account,
                    amounts: [Amount(commodity: commodity, quantity: qty)]
                ))
            }
        }

        guard postings.count >= 2 else { return }

        let ruleId = editingRule?.ruleId ?? UUID().uuidString.prefix(8).lowercased()

        let rule = RecurringRule(
            ruleId: String(ruleId),
            periodExpr: periodExpr,
            description: description,
            postings: postings,
            startDate: startDate.isEmpty ? nil : startDate,
            endDate: endDate.isEmpty ? nil : endDate
        )

        onSave(rule)
        dismiss()
    }
}
