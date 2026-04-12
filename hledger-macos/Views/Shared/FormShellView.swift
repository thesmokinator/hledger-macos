/// Reusable form shell layout for transaction-style forms.
///
/// Provides a centered title (inside the scrolling area), a scrollable content
/// region, a divider, and a footer with an optional error message + Cancel /
/// Save buttons. The frame size is set by the caller via `.frame()` on the
/// result so the three forms (Transaction, Recurring, Budget) can keep their
/// own dimensions.
///
/// Used by TransactionFormView, RecurringFormView, and BudgetFormView. See #86.

import SwiftUI

struct FormShellView<Content: View>: View {
    let title: String
    let errorMessage: String?
    let saveDisabled: Bool
    let saveHint: String?
    let onCancel: () -> Void
    let onSave: () -> Void
    let content: () -> Content

    init(
        title: String,
        errorMessage: String? = nil,
        saveDisabled: Bool = false,
        saveHint: String? = nil,
        onCancel: @escaping () -> Void,
        onSave: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.errorMessage = errorMessage
        self.saveDisabled = saveDisabled
        self.saveHint = saveHint
        self.onCancel = onCancel
        self.onSave = onSave
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Centered title
                    HStack {
                        Spacer()
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(Color.accentColor)
                        Spacer()
                    }
                    .padding(.top, Theme.Spacing.xl)
                    .padding(.bottom, Theme.Spacing.xl)

                    content()
                }
            }

            Divider()

            // Footer
            HStack {
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(Theme.Status.critical)
                        .lineLimit(2)
                }

                Spacer()

                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)

                Button("Save", action: onSave)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(saveDisabled)
                    .help(saveDisabled ? (saveHint ?? "") : "")
            }
            .padding(.horizontal, Theme.Spacing.xxl)
            .padding(.vertical, Theme.Spacing.md)
        }
    }
}
