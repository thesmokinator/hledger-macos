/// Reusable summary card for displaying Income, Expenses, Net values.
/// Shows a spinner while loading, formatted amount when data is available.

import SwiftUI

struct SummaryCard: View {
    let title: String
    let summary: PeriodSummary?
    let value: KeyPath<PeriodSummary, Decimal>
    let color: Color
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)

            Group {
                if let summary {
                    Text(AmountFormatter.format(summary[keyPath: value], commodity: summary.commodity))
                        .foregroundStyle(color)
                } else {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .font(.system(.title, design: .rounded, weight: .bold))
            .frame(height: 28)

            Text(subtitle ?? " ")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
    }
}
