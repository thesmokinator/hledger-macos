/// Inner form body for `TransactionFormView` — the fields and postings
/// area that lives inside the `FormShellView`'s scroll content. Holds the
/// `@FocusState` for the Code / Comment text fields (which can't live in
/// `TransactionFormState` because `@FocusState` requires a SwiftUI view
/// context). See #92.

import SwiftUI

struct TransactionFormContent: View {
    @Bindable var state: TransactionFormState
    let defaultCommodity: String

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case code, comment
    }

    var body: some View {
        // Fields
        VStack(spacing: 14) {
            FormRow("Date:", required: true) {
                DateInputField(year: $state.dateYear, month: $state.dateMonth, day: $state.dateDay)
                    .help("Format: YYYY-MM-DD")
            }

            FormRow("Description:", required: true) {
                AutocompleteField(
                    placeholder: "Transaction description",
                    text: $state.description,
                    suggestions: state.knownDescriptions
                )
            }

            FormRow("Status:") {
                HStack {
                    Picker("", selection: $state.status) {
                        Text("Unmarked").tag(TransactionStatus.unmarked)
                        Text("Pending").tag(TransactionStatus.pending)
                        Text("Cleared").tag(TransactionStatus.cleared)
                    }
                    .labelsHidden()
                    .fixedSize()
                    Spacer()
                }
            }

            FormRow("Code:") {
                TextField("Optional transaction code", text: $state.code)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .code)
            }

            FormRow("Comment:") {
                TextField("Optional comment", text: $state.comment)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .comment)
            }
        }
        .padding(.horizontal, Theme.Spacing.xxl)

        // Postings
        VStack(alignment: .leading, spacing: 8) {
            Divider().padding(.vertical, Theme.Spacing.md)

            Text("Postings")
                .font(.subheadline.bold())

            Text("Amount: plain number (50.00), currency prefix (\(defaultCommodity)50.00), or commodity with cost (-5 STCK @@ \(defaultCommodity)200.00). Leave one amount blank to auto-balance.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, Theme.Spacing.xs)

            Text("Default commodity: \(defaultCommodity)")
                .font(.caption.italic())
                .foregroundStyle(.tertiary)
                .padding(.bottom, Theme.Spacing.sm)

            ForEach(Array(state.postingRows.enumerated()), id: \.element.id) { index, _ in
                PostingRowField(
                    index: index,
                    account: $state.postingRows[index].account,
                    amount: $state.postingRows[index].amount,
                    comment: $state.postingRows[index].comment,
                    suggestions: state.knownAccounts,
                    showRemove: state.postingRows.count > 2,
                    onRemove: { state.postingRows.remove(at: index) }
                )
            }

            Button {
                state.postingRows.append(PostingRow())
            } label: {
                Label("Add Posting", systemImage: "plus")
            }
            .controlSize(.small)
            .padding(.top, Theme.Spacing.xs)
        }
        .padding(.horizontal, Theme.Spacing.xxl)
        .padding(.bottom, Theme.Spacing.lg)
    }
}
