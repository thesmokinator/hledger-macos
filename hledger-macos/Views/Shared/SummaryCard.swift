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
        VStack(spacing: 6) {
            Text(title)
                .font(.body)
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
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .frame(height: 34)

            Text(subtitle ?? " ")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
    }
}
