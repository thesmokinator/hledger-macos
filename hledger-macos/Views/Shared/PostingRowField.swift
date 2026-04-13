/// Reusable posting row for transaction, recurring, and budget forms.
/// Shows account (with autocomplete), amount, optional comment, and remove button.

import SwiftUI

struct PostingRowField: View {
    let index: Int
    @Binding var account: String
    @Binding var amount: String
    @Binding var comment: String
    let suggestions: [String]
    let showRemove: Bool
    let onRemove: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Text("#\(index + 1):")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 30, alignment: .trailing)
                    .accessibilityHidden(true)

                AutocompleteField(
                    placeholder: "e.g. expenses:food",
                    text: $account,
                    suggestions: suggestions
                )
                .accessibilityLabel("Posting \(index + 1) account")

                TextField("0.00", text: $amount)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 130)
                    .accessibilityLabel("Posting \(index + 1) amount")

                if showRemove {
                    Button {
                        onRemove()
                    } label: {
                        Image(systemName: "minus.circle").foregroundStyle(.red)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Remove posting \(index + 1)")
                }
            }

            if !comment.isEmpty || !account.isEmpty {
                HStack(spacing: 8) {
                    Spacer().frame(width: 30)
                    TextField("Posting comment", text: $comment)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Posting \(index + 1) comment")
                }
            }
        }
    }
}
