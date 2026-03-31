/// Form for adding or editing a budget rule.

import SwiftUI

struct BudgetFormView: View {
    let editingRule: BudgetRule?
    let knownAccounts: [String]
    let onSave: (BudgetRule) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var account = ""
    @State private var amount = ""
    @State private var category = ""

    private var isEditing: Bool { editingRule != nil }
    private var title: String { isEditing ? "Edit Budget Rule" : "New Budget Rule" }

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.accentColor)
                .padding(.top, 20)
                .padding(.bottom, 16)

            Form {
                Section("Account") {
                    AutocompleteField(
                        placeholder: "e.g. expenses:groceries",
                        text: $account,
                        suggestions: knownAccounts
                    )
                }

                Section("Monthly Budget") {
                    TextField("e.g. 500.00", text: $amount)
                }

                Section("Category (optional)") {
                    TextField("e.g. Food, Housing", text: $category)
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
                    .disabled(account.isEmpty || amount.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .frame(width: 420, height: 360)
        .onAppear { prefill() }
    }

    private func prefill() {
        if let rule = editingRule {
            account = rule.account
            amount = rule.amount.formatted()
            category = rule.category
        }
    }

    private func save() {
        let (qty, commodity) = AmountParser.parse(amount)
        guard qty != 0 else { return }

        let rule = BudgetRule(
            account: account,
            amount: Amount(commodity: commodity, quantity: qty),
            category: category
        )
        onSave(rule)
        dismiss()
    }
}
