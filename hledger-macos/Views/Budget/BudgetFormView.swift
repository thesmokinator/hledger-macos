/// Form for adding or editing a budget rule.
/// Same layout style as TransactionFormView.

import SwiftUI

struct BudgetFormView: View {
    let editingRule: BudgetRule?
    let knownAccounts: [String]
    let onSave: (BudgetRule) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var account = ""
    @State private var amount = ""
    @State private var category = ""
    @State private var errorMessage: String?

    private var isEditing: Bool { editingRule != nil }
    private var title: String { isEditing ? "Edit Budget Rule" : "New Budget Rule" }
    private let labelWidth: CGFloat = 90

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
                        formRow("Account:") {
                            AutocompleteField(
                                placeholder: "e.g. expenses:groceries",
                                text: $account,
                                suggestions: knownAccounts
                            )
                        }

                        formRow("Amount:") {
                            TextField("e.g. 500.00", text: $amount)
                                .textFieldStyle(.roundedBorder)
                        }

                        formRow("Category:") {
                            TextField("e.g. Food, Housing (optional)", text: $category)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    .padding(.horizontal, 24)
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
                    .disabled(account.isEmpty || amount.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .frame(width: 480, height: 300)
        .onAppear { prefill() }
    }

    // MARK: - Form Row

    private func formRow<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: labelWidth, alignment: .trailing)
                .padding(.top, 6)
            content()
        }
    }

    // MARK: - Prefill

    private func prefill() {
        if let rule = editingRule {
            account = rule.account
            amount = rule.amount.formatted()
            category = rule.category
        }
    }

    // MARK: - Save

    private func save() {
        let (qty, commodity) = AmountParser.parse(amount)
        guard qty != 0 else {
            errorMessage = "Invalid amount"
            return
        }

        let rule = BudgetRule(
            account: account,
            amount: Amount(commodity: commodity, quantity: qty),
            category: category
        )
        onSave(rule)
        dismiss()
    }
}
