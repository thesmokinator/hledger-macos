/// Reusable month / period navigator with previous-next chevrons.
/// Used by TransactionsView and BudgetView.

import SwiftUI

struct PeriodNavigator: View {
    let label: String
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack {
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
                    .font(.title3)
            }
            .buttonStyle(.borderless)
            .keyboardShortcut(.leftArrow, modifiers: [])
            .accessibilityLabel("Previous month")

            Spacer()

            Text(label)
                .font(.title2.bold())

            Spacer()

            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .font(.title3)
            }
            .buttonStyle(.borderless)
            .keyboardShortcut(.rightArrow, modifiers: [])
            .accessibilityLabel("Next month")
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.lg)
    }
}
