/// Chart overlay for financial reports — shows bar chart visualization.
/// Presented as a sheet with translucent material background.

import SwiftUI
import Charts

struct ReportChartOverlay: View {
    let reportType: ReportType
    let data: ReportData
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(reportType.displayName)
                    .font(.headline)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 12)

            // Chart
            Group {
                switch reportType {
                case .incomeStatement:
                    incomeStatementChart
                case .balanceSheet:
                    singleSeriesChart(title: "Net Assets")
                case .cashFlow:
                    singleSeriesChart(title: "Cash Flow")
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(width: 860, height: 560)
        .background(.ultraThinMaterial)
    }

    // MARK: - Income Statement Chart (Income vs Expenses)

    private var incomeStatementChart: some View {
        let chartData = extractISData()

        return Chart {
            ForEach(chartData, id: \.period) { item in
                BarMark(
                    x: .value("Period", item.period),
                    y: .value("Amount", item.income)
                )
                .foregroundStyle(.green.opacity(0.8))
                .position(by: .value("Type", "Income"))

                BarMark(
                    x: .value("Period", item.period),
                    y: .value("Amount", item.expenses)
                )
                .foregroundStyle(.red.opacity(0.8))
                .position(by: .value("Type", "Expenses"))
            }

            ForEach(chartData, id: \.period) { item in
                LineMark(
                    x: .value("Period", item.period),
                    y: .value("Net", item.net)
                )
                .foregroundStyle(.primary)
                .lineStyle(StrokeStyle(lineWidth: 2))

                PointMark(
                    x: .value("Period", item.period),
                    y: .value("Net", item.net)
                )
                .foregroundStyle(.primary)
                .symbolSize(30)
            }
        }
        .chartForegroundStyleScale([
            "Income": Color.green.opacity(0.8),
            "Expenses": Color.red.opacity(0.8)
        ])
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(formatAxisValue(v))
                            .font(.caption2)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .font(.caption2)
            }
        }
    }

    // MARK: - Single Series Chart (BS, CF)

    private func singleSeriesChart(title: String) -> some View {
        let chartData = extractTotalData()

        return Chart {
            ForEach(chartData, id: \.period) { item in
                BarMark(
                    x: .value("Period", item.period),
                    y: .value("Amount", item.value)
                )
                .foregroundStyle(item.value >= 0 ? Color.green.opacity(0.8) : Color.red.opacity(0.8))
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(formatAxisValue(v))
                            .font(.caption2)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .font(.caption2)
            }
        }
    }

    // MARK: - Data Extraction

    private struct ISDataPoint {
        let period: String
        let income: Double
        let expenses: Double
        var net: Double { income - expenses }
    }

    private struct TotalDataPoint {
        let period: String
        let value: Double
    }

    private func extractISData() -> [ISDataPoint] {
        let headers = data.periodHeaders.map { formatPeriodShort($0) }

        // Find total rows for revenue and expenses
        var incomeTotals: [Double] = []
        var expenseTotals: [Double] = []

        for row in data.rows {
            if row.isTotal {
                let values = row.amounts.map { parseAmount($0) }
                // First "Total:" is revenue, second is expenses
                if incomeTotals.isEmpty {
                    incomeTotals = values
                } else if expenseTotals.isEmpty {
                    expenseTotals = values
                }
            }
        }

        // Fallback: if we couldn't find totals, use Net row
        guard !incomeTotals.isEmpty else { return [] }
        if expenseTotals.isEmpty {
            expenseTotals = Array(repeating: 0.0, count: incomeTotals.count)
        }

        return zip(headers, zip(incomeTotals, expenseTotals)).map { period, values in
            ISDataPoint(period: period, income: abs(values.0), expenses: abs(values.1))
        }
    }

    private func extractTotalData() -> [TotalDataPoint] {
        let headers = data.periodHeaders.map { formatPeriodShort($0) }

        // Find the last total/net row
        guard let netRow = data.rows.last(where: { $0.isTotal }) else { return [] }
        let values = netRow.amounts.map { parseAmount($0) }

        return zip(headers, values).map { TotalDataPoint(period: $0, value: $1) }
    }

    // MARK: - Helpers

    private func parseAmount(_ raw: String) -> Double {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != "0" else { return 0 }
        let (qty, _) = AmountParser.parse(trimmed)
        return NSDecimalNumber(decimal: qty).doubleValue
    }

    private func formatPeriodShort(_ header: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        guard let date = f.date(from: header) else { return header }
        let display = DateFormatter()
        display.dateFormat = "MMM"
        return display.string(from: date)
    }

    private func formatAxisValue(_ value: Double) -> String {
        if abs(value) >= 1000 {
            return "\(Int(value / 1000))k"
        }
        return "\(Int(value))"
    }
}
