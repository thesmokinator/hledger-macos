/// Financial reports view: Income Statement, Balance Sheet, Cash Flow.

import SwiftUI

enum PeriodRange: Int, CaseIterable, Identifiable {
    case threeMonths = 3
    case sixMonths = 6
    case twelveMonths = 12
    case yearToDate = 0

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .threeMonths: return "3 months"
        case .sixMonths: return "6 months"
        case .twelveMonths: return "12 months"
        case .yearToDate: return "Year to date"
        }
    }
}

struct ReportsView: View {
    @Environment(AppState.self) private var appState

    @State private var reportType: ReportType = .incomeStatement
    @State private var periodRange: PeriodRange = .sixMonths
    @State private var reportData: ReportData?
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                Spacer()
                ProgressView("Loading report...")
                Spacer()
            } else if let data = reportData, !data.rows.isEmpty {
                reportContent(data)
            } else {
                Spacer()
                ContentUnavailableView(
                    "No Data",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("No report data for the selected period.")
                )
                Spacer()
            }
        }
        .navigationTitle("Reports")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Picker("Report", selection: $reportType) {
                    ForEach(ReportType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .frame(width: 170)

                Picker("Period", selection: $periodRange) {
                    ForEach(PeriodRange.allCases) { range in
                        Text(range.label).tag(range)
                    }
                }
                .frame(width: 130)
            }
        }
        .task { await loadReport() }
        .onChange(of: reportType) { Task { await loadReport() } }
        .onChange(of: periodRange) { Task { await loadReport() } }
    }

    // MARK: - Report Content

    private func reportContent(_ data: ReportData) -> some View {
        List {
            // Header
            HStack(spacing: 0) {
                Text("Account")
                    .frame(width: 200, alignment: .leading)

                ForEach(data.periodHeaders, id: \.self) { header in
                    Text(formatPeriodHeader(header))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .listRowSeparator(.visible)

            // Rows
            ForEach(data.rows) { row in
                HStack(spacing: 0) {
                    Text(row.account)
                        .font(row.isSectionHeader || row.isTotal ? .callout.bold() : .callout)
                        .foregroundColor(row.isSectionHeader ? .accentColor : .primary)
                        .frame(width: 200, alignment: .leading)
                        .lineLimit(1)

                    ForEach(Array(row.amounts.enumerated()), id: \.offset) { _, amount in
                        Text(formatReportAmount(amount))
                            .font(.system(.callout, design: .monospaced))
                            .foregroundStyle(amountColor(amount, isTotal: row.isTotal))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .padding(.vertical, row.isSectionHeader ? 4 : 1)
                .listRowBackground(row.isTotal ? Color.secondary.opacity(0.08) : Color.clear)
            }
        }
        .listStyle(.inset)
    }

    // MARK: - Formatting

    private func formatPeriodHeader(_ header: String) -> String {
        // Convert "2025-10" to "Oct 2025"
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        guard let date = f.date(from: header) else { return header }
        let display = DateFormatter()
        display.dateFormat = "MMM yyyy"
        return display.string(from: date)
    }

    private func formatReportAmount(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != "0" else { return "" }
        let (qty, commodity) = AmountParser.parse(trimmed)
        if qty == 0 && commodity.isEmpty { return trimmed }
        return AmountFormatter.format(qty, commodity: commodity)
    }

    private func amountColor(_ amount: String, isTotal: Bool) -> Color {
        let trimmed = amount.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed == "0" { return .gray }
        if trimmed.hasPrefix("-") { return .red }
        if isTotal { return .primary }
        return .secondary
    }

    // MARK: - Data Loading

    private func loadReport() async {
        guard let backend = appState.activeBackend else { return }
        isLoading = true

        let (begin, end) = periodDates()
        let commodity = appState.config.defaultCommodity.isEmpty ? nil : appState.config.defaultCommodity

        do {
            reportData = try await backend.loadReport(
                type: reportType,
                periodBegin: begin,
                periodEnd: end,
                commodity: commodity
            )
        } catch {
            print("Report load error: \(error)")
            reportData = nil
        }

        isLoading = false
    }

    private func periodDates() -> (String, String) {
        let calendar = Calendar.current
        let now = Date()
        let endComponents = calendar.dateComponents([.year, .month], from: now)
        let startOfMonth = calendar.date(from: endComponents)!
        let endDate = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!

        let beginDate: Date
        if periodRange == .yearToDate {
            var ytd = calendar.dateComponents([.year], from: now)
            ytd.month = 1
            ytd.day = 1
            beginDate = calendar.date(from: ytd)!
        } else {
            beginDate = calendar.date(byAdding: .month, value: -periodRange.rawValue, to: startOfMonth)!
        }

        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return (f.string(from: beginDate), f.string(from: endDate))
    }
}
