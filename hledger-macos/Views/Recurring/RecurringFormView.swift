/// Form for adding or editing a recurring transaction rule.
/// Same layout style as TransactionFormView.

import SwiftUI

struct RecurringFormView: View {
    let editingRule: RecurringRule?
    let knownAccounts: [String]
    let onSave: (RecurringRule) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var periodExpr = "monthly"
    @State private var description = ""
    @State private var startYear = ""
    @State private var startMonth = ""
    @State private var startDay = ""
    @State private var endYear = ""
    @State private var endMonth = ""
    @State private var endDay = ""
    @State private var postingRows: [PostingRow] = [PostingRow(), PostingRow()]
    @State private var errorMessage: String?

    private var isEditing: Bool { editingRule != nil }
    private var title: String { isEditing ? "Edit Recurring Rule" : "New Recurring Rule" }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Title
                    HStack {
                        Spacer()
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(Color.accentColor)
                        Spacer()
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 20)

                    // Fields
                    VStack(spacing: 14) {
                        FormRow("Period:") {
                            HStack {
                                Picker("", selection: $periodExpr) {
                                    ForEach(RecurringManager.supportedPeriods, id: \.self) { period in
                                        Text(period.capitalized).tag(period)
                                    }
                                }
                                .labelsHidden()
                                .fixedSize()
                                Spacer()
                            }
                        }

                        FormRow("Description:") {
                            TextField("Recurring transaction description", text: $description)
                                .textFieldStyle(.roundedBorder)
                        }

                        FormRow("Start date:") {
                            DateInputField(year: $startYear, month: $startMonth, day: $startDay)
                        }

                        FormRow("End date:") {
                            DateInputField(year: $endYear, month: $endMonth, day: $endDay, optional: true)
                        }
                    }
                    .padding(.horizontal, 24)

                    // Postings
                    VStack(alignment: .leading, spacing: 8) {
                        Divider().padding(.vertical, 12)

                        Text("Postings")
                            .font(.subheadline.bold())

                        Text("Leave one amount blank for auto-balance.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 8)

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
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 130)

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
                        .controlSize(.small)
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }
            }

            Divider()

            // Footer
            HStack {
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }

                Spacer()

                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(description.isEmpty || startYear.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .frame(width: 560, height: 520)
        .onAppear { prefill() }
    }

    // MARK: - Prefill

    private func prefill() {
        if let rule = editingRule {
            periodExpr = rule.periodExpr
            description = rule.description
            splitDate(rule.startDate, year: &startYear, month: &startMonth, day: &startDay)
            splitDate(rule.endDate, year: &endYear, month: &endMonth, day: &endDay)
            postingRows = rule.postings.map {
                PostingRow(
                    account: $0.account,
                    amount: $0.amounts.first.map { $0.formatted() } ?? ""
                )
            }
        }
        while postingRows.count < 2 { postingRows.append(PostingRow()) }

        if startYear.isEmpty {
            let f = DateFormatter()
            f.dateFormat = "yyyy"; startYear = f.string(from: Date())
            f.dateFormat = "MM"; startMonth = f.string(from: Date())
            f.dateFormat = "dd"; startDay = f.string(from: Date())
        }
    }

    private func splitDate(_ date: String?, year: inout String, month: inout String, day: inout String) {
        guard let date, !date.isEmpty else { return }
        let parts = date.split(separator: "-").map(String.init)
        if parts.count > 0 { year = parts[0] }
        if parts.count > 1 { month = parts[1] }
        if parts.count > 2 { day = parts[2] }
    }

    // MARK: - Save

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

        guard postings.count >= 2 else {
            errorMessage = "At least 2 postings required"
            return
        }

        let ruleId = editingRule?.ruleId ?? String(UUID().uuidString.prefix(8)).lowercased()

        let startDateStr = startYear.isEmpty ? nil : "\(startYear)-\(startMonth)-\(startDay)"
        let endDateStr = endYear.isEmpty ? nil : "\(endYear)-\(endMonth)-\(endDay)"

        let rule = RecurringRule(
            ruleId: ruleId,
            periodExpr: periodExpr,
            description: description,
            postings: postings,
            startDate: startDateStr,
            endDate: endDateStr
        )

        onSave(rule)
        dismiss()
    }
}
