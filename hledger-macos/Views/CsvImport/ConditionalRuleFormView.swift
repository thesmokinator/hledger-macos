/// Form for adding or editing a conditional rule (pattern → account mapping).

import SwiftUI

struct ConditionalRuleFormView: View {
    let editingRule: ConditionalRule?
    let knownAccounts: [String]
    let onSave: (ConditionalRule) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var pattern = ""
    @State private var account = ""
    @State private var comment = ""
    @State private var errorMessage: String?

    private var isEditing: Bool { editingRule != nil }
    private var title: String { isEditing ? "Edit Rule" : "New Rule" }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Spacer()
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(Color.accentColor)
                        Spacer()
                    }
                    .padding(.top, Theme.Spacing.xl)
                    .padding(.bottom, Theme.Spacing.xl)

                    VStack(spacing: 14) {
                        FormRow("Pattern:", labelWidth: 80) {
                            TextField("e.g. grocery|supermarket", text: $pattern)
                                .textFieldStyle(.roundedBorder)
                        }

                        FormRow("Account:", labelWidth: 80) {
                            AutocompleteField(
                                placeholder: "e.g. expenses:groceries",
                                text: $account,
                                suggestions: knownAccounts
                            )
                        }

                        FormRow("Comment:", labelWidth: 80) {
                            TextField("Optional", text: $comment)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.xxl)
                }
            }

            Divider()

            HStack {
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(Theme.Status.critical)
                        .lineLimit(2)
                }

                Spacer()

                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(pattern.isEmpty || account.isEmpty)
            }
            .padding(.horizontal, Theme.Spacing.xxl)
            .padding(.vertical, Theme.Spacing.md)
        }
        .frame(width: 440, height: 280)
        .onAppear { prefill() }
    }

    private func prefill() {
        if let rule = editingRule {
            pattern = rule.pattern
            account = rule.account
            comment = rule.comment
        }
    }

    private func save() {
        guard !pattern.isEmpty else {
            errorMessage = String(localized: "Pattern is required")
            return
        }
        guard !account.isEmpty else {
            errorMessage = String(localized: "Account is required")
            return
        }

        let rule = ConditionalRule(
            id: editingRule?.id ?? UUID(),
            pattern: pattern,
            account: account,
            comment: comment
        )
        onSave(rule)
        dismiss()
    }
}
