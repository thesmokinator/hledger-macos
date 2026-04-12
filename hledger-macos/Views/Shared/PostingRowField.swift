/// Reusable posting row for transaction, recurring, and budget forms.
/// Row 1: index label · account field · remove button
/// Row 2: (indented) amount field · comment field

import SwiftUI

struct PostingRowField: View {
    let index: Int
    @Binding var account: String
    @Binding var amount: String
    @Binding var comment: String
    let suggestions: [String]
    let showRemove: Bool
    let onRemove: () -> Void

    private let indexWidth: CGFloat = 30

    var body: some View {
        VStack(spacing: 4) {
            // Row 1: account
            HStack(spacing: 8) {
                Text("#\(index + 1):")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: indexWidth, alignment: .trailing)

                AutocompleteField(
                    placeholder: "e.g. expenses:food",
                    text: $account,
                    suggestions: suggestions
                )

                if showRemove {
                    Button {
                        onRemove()
                    } label: {
                        Image(systemName: "minus.circle").foregroundStyle(Theme.Status.critical)
                    }
                    .buttonStyle(.borderless)
                }
            }

            // Row 2: amount + comment, indented to align with account
            HStack(spacing: 8) {
                Spacer().frame(width: indexWidth)

                TextField("0.00", text: $amount)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.callout, design: .monospaced))
                    .frame(minWidth: 140, maxWidth: 240)

                TextField("Posting comment (optional)", text: $comment)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
