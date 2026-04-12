/// Form for adding or editing a budget rule.
/// Same layout style as TransactionFormView.

import SwiftUI

struct BudgetFormView: View {
    let editingRule: BudgetRule?
    let knownAccounts: [String]
    let onSave: (BudgetRule) -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var account = ""
    @State private var amount = ""
    @State private var category = ""
    @State private var errorMessage: String?

    private var saveHint: String {
        var missing: [String] = []
        if account.isEmpty { missing.append("an account") }
        if amount.isEmpty { missing.append("an amount") }
        guard !missing.isEmpty else { return "" }
        return "Required: \(missing.joined(separator: ", "))"
    }

    private var isEditing: Bool { editingRule != nil }
    private var title: String { isEditing ? "Edit Budget Rule" : "New Budget Rule" }

    var body: some View {
        FormShellView(
            title: title,
            errorMessage: errorMessage,
            saveDisabled: account.isEmpty || amount.isEmpty,
            saveHint: saveHint,
            onCancel: { dismiss() },
            onSave: { save() }
        ) {
            VStack(spacing: 14) {
                FormRow("Account:", required: true) {
                    AutocompleteField(
                        placeholder: "e.g. expenses:groceries",
                        text: $account,
                        suggestions: knownAccounts
                    )
                }

                FormRow("Amount:", required: true) {
                    TextField("e.g. 500.00", text: $amount)
                        .textFieldStyle(.roundedBorder)
                        .help("Monthly budget amount (e.g. 500.00)")
                }

                FormRow("Category:") {
                    TextField("e.g. Food, Housing (optional)", text: $category)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding(.horizontal, Theme.Spacing.xxl)
        }
        .frame(width: 480, height: 300)
        .onAppear { prefill() }
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
        guard let parsed = appState.parseFormAmount(amount), parsed.quantity != 0 else {
            errorMessage = "Invalid amount"
            return
        }

        let rule = BudgetRule(
            account: account,
            amount: parsed,
            category: category
        )
        onSave(rule)
        dismiss()
    }
}
