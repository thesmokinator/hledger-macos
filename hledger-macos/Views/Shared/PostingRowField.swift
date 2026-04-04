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

                AutocompleteField(
                    placeholder: "e.g. expenses:food",
                    text: $account,
                    suggestions: suggestions
                )

                TextField("0.00", text: $amount)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 130)

                if showRemove {
                    Button {
                        onRemove()
                    } label: {
                        Image(systemName: "minus.circle").foregroundStyle(.red)
                    }
                    .buttonStyle(.borderless)
                }
            }

            if !comment.isEmpty || !account.isEmpty {
                HStack(spacing: 8) {
                    Spacer().frame(width: 30)
                    TextField("Posting comment", text: $comment)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
