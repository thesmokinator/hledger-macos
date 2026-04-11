/// Sheet for creating, editing, or cloning a transaction.
///
/// Thin wrapper around `FormShellView` and `TransactionFormContent`. The
/// form data and save/validation logic live in `TransactionFormState`.
/// See #86 (FormShellView extraction) and #92 (this view's split).

import SwiftUI

struct TransactionFormView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let editingTransaction: Transaction?
    let isClone: Bool

    @State private var formState: TransactionFormState

    init(editingTransaction: Transaction?, isClone: Bool) {
        self.editingTransaction = editingTransaction
        self.isClone = isClone
        self._formState = State(initialValue: TransactionFormState(
            editingTransaction: editingTransaction,
            isClone: isClone
        ))
    }

    var body: some View {
        FormShellView(
            title: formState.title,
            errorMessage: formState.errorMessage,
            saveDisabled: formState.isSaving || !formState.isDateValid,
            onCancel: { dismiss() },
            onSave: { Task { await performSave() } }
        ) {
            TransactionFormContent(
                state: formState,
                defaultCommodity: appState.config.defaultCommodity
            )
        }
        .frame(width: 560, height: 580)
        .task { await formState.loadAutocompleteData(from: appState.activeBackend) }
        .onAppear { formState.prefill() }
    }

    private func performSave() async {
        if await formState.save(using: appState) {
            dismiss()
        }
    }
}
