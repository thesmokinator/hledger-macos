/// Form for adding or editing a recurring transaction rule.
/// Same layout style as TransactionFormView.

import SwiftUI

struct RecurringFormView: View {
    let editingRule: RecurringRule?
    let knownAccounts: [String]
    let onSave: (RecurringRule) -> Void

    @Environment(AppState.self) private var appState
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

    private var saveHint: String {
        var missing: [String] = []
        if description.isEmpty { missing.append("a description") }
        if startYear.isEmpty { missing.append("a start date") }
        guard !missing.isEmpty else { return "" }
        return "Required: \(missing.joined(separator: ", "))"
    }

    var body: some View {
        FormShellView(
            title: title,
            errorMessage: errorMessage,
            saveDisabled: description.isEmpty || startYear.isEmpty,
            saveHint: saveHint,
            onCancel: { dismiss() },
            onSave: { save() }
        ) {
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

                FormRow("Description:", required: true) {
                    TextField("Recurring transaction description", text: $description)
                        .textFieldStyle(.roundedBorder)
                }

                FormRow("Start date:", required: true) {
                    DateInputField(year: $startYear, month: $startMonth, day: $startDay)
                        .help("Format: YYYY-MM-DD")
                }

                FormRow("End date:") {
                    DateInputField(year: $endYear, month: $endMonth, day: $endDay, optional: true)
                }
            }
            .padding(.horizontal, Theme.Spacing.xxl)

            // Postings
            VStack(alignment: .leading, spacing: 8) {
                Divider().padding(.vertical, Theme.Spacing.md)

                Text("Postings")
                    .font(.subheadline.bold())

                Text("Leave one amount blank for auto-balance.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, Theme.Spacing.sm)

                ForEach(Array(postingRows.enumerated()), id: \.element.id) { index, _ in
                    PostingRowField(
                        index: index,
                        account: $postingRows[index].account,
                        amount: $postingRows[index].amount,
                        comment: .constant(""),
                        suggestions: knownAccounts,
                        showRemove: postingRows.count > 2,
                        onRemove: { postingRows.remove(at: index) }
                    )
                }

                Button {
                    postingRows.append(PostingRow())
                } label: {
                    Label("Add Posting", systemImage: "plus")
                }
                .controlSize(.small)
                .padding(.top, Theme.Spacing.xs)
            }
            .padding(.horizontal, Theme.Spacing.xxl)
            .padding(.bottom, Theme.Spacing.lg)
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
            if let amount = appState.parseFormAmount(row.amount) {
                postings.append(Posting(account: row.account, amounts: [amount]))
            } else {
                // Empty or unparseable input → posting with no amount (auto-balance).
                postings.append(Posting(account: row.account))
            }
        }

        guard postings.count >= 2 else {
            errorMessage = String(localized: "At least 2 postings required")
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
