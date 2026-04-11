/// Reusable delete-confirmation alert modifier.
/// Standardizes the Cancel / Delete button pair used by views that
/// confirm destructive actions on a single item.

import SwiftUI

extension View {
    /// Presents a standard "Delete X?" confirmation alert with
    /// Cancel (default) and Delete (destructive) buttons.
    ///
    /// - Parameters:
    ///   - isPresented: Binding controlling alert visibility.
    ///   - itemName: Singular item label used in the alert title
    ///     (e.g. "Recurring Rule" → "Delete Recurring Rule?").
    ///   - message: Body text shown under the title.
    ///   - onConfirm: Action invoked when the user confirms deletion.
    func confirmDeleteAlert(
        isPresented: Binding<Bool>,
        itemName: String,
        message: String,
        onConfirm: @escaping () -> Void
    ) -> some View {
        self.alert("Delete \(itemName)?", isPresented: isPresented) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive, action: onConfirm)
        } message: {
            Text(message)
        }
    }
}
