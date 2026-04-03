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
    @State private var showingChart = false

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
                Menu {
                    Button("Export as CSV") { if let data = reportData { ExportService.exportReport(data, format: .csv) } }
                    Button("Export as PDF") { if let data = reportData { ExportService.exportReport(data, format: .pdf) } }
                } label: {
                    Label("Export", systemImage: "arrow.down.doc")
                }
                .disabled(reportData == nil || reportData?.rows.isEmpty == true)

                Button {
                    showingChart = true
                } label: {
                    Label("Chart", systemImage: "chart.bar")
                }
                .disabled(reportData == nil || reportData?.rows.isEmpty == true)

                Menu {
                    ForEach(ReportType.allCases, id: \.self) { type in
                        Button {
                            reportType = type
                        } label: {
                            if type == reportType {
                                Label(type.displayName, systemImage: "checkmark")
                            } else {
                                Text(type.displayName)
                            }
                        }
                    }
                } label: {
                    Text(reportType.displayName)
                        .font(.callout)
                }

                Menu {
                    ForEach(PeriodRange.allCases) { range in
                        Button {
                            periodRange = range
                        } label: {
                            if range == periodRange {
                                Label(range.label, systemImage: "checkmark")
                            } else {
                                Text(range.label)
                            }
                        }
                    }
                } label: {
                    Text(periodRange.label)
                        .font(.callout)
                }
            }
        }
        .task(id: appState.dataVersion) { await loadReport() }
        .onChange(of: reportType) { Task { await loadReport() } }
        .onChange(of: periodRange) { Task { await loadReport() } }
        .sheet(isPresented: $showingChart) {
            if let data = reportData {
                ReportChartOverlay(reportType: reportType, data: data)
            }
        }
    }

    // MARK: - Report Content

    private func reportContent(_ data: ReportData) -> some View {
        List {
            ReportHeaderRow(
                accountLabel: "Account",
                periodHeaders: data.periodHeaders,
                formatHeader: formatPeriodHeader
            )

            ForEach(Array(data.rows.enumerated()), id: \.element.id) { index, row in
                ReportRowView(
                    account: row.account,
                    amounts: row.amounts,
                    isSectionHeader: row.isSectionHeader,
                    isTotal: row.isTotal,
                    formatAmount: formatReportAmount,
                    amountColor: { amountColor($0, isTotal: row.isTotal) }
                )
                if row.isTotal && index + 1 < data.rows.count && !data.rows[index + 1].isTotal {
                    Spacer().frame(height: 8).listRowSeparator(.hidden)
                }
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
        if trimmed.isEmpty || trimmed == "0" { return "" }
        return trimmed
    }

    private func isNegativeAmount(_ text: String) -> Bool {
        text.contains("-")
    }

    private func amountColor(_ amount: String, isTotal: Bool) -> Color {
        let trimmed = amount.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed == "0" { return .gray }
        if isNegativeAmount(trimmed) { return .red }
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
            appState.errorMessage = error.localizedDescription
            reportData = nil
        }

        isLoading = false
    }

    private func periodDates() -> (String, String) {
        let calendar = Calendar.current
        let now = Date()
        let endComponents = calendar.dateComponents([.year, .month], from: now)
        let startOfMonth = calendar.date(from: endComponents)!
        // End = first day of next month (exclusive in hledger)
        let endDate = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!

        let beginDate: Date
        if periodRange == .yearToDate {
            var ytd = calendar.dateComponents([.year], from: now)
            ytd.month = 1
            ytd.day = 1
            beginDate = calendar.date(from: ytd)!
        } else {
            // -b is inclusive, so for "3 months" we want current month minus 2
            // e.g. March 2026 with 3 months → Jan 2026 (Jan, Feb, Mar)
            beginDate = calendar.date(byAdding: .month, value: -(periodRange.rawValue - 1), to: startOfMonth)!
        }

        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return (f.string(from: beginDate), f.string(from: endDate))
    }
}
