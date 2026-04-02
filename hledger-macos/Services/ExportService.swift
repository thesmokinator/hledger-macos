/// Export service for saving data as CSV or PDF.

import AppKit
import Foundation
import UniformTypeIdentifiers

enum ExportService {
    // MARK: - CSV Export

    static func exportCSV(filename: String, headers: [String], rows: [[String]]) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = filename
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        var csv = headers.map { escapeCSV($0) }.joined(separator: ",") + "\n"
        for row in rows {
            csv += row.map { escapeCSV($0) }.joined(separator: ",") + "\n"
        }

        try? csv.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - PDF Export

    static func exportPDF(filename: String, title: String, headers: [String], rows: [[String]]) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = filename
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let pageWidth: CGFloat = 842  // A4 landscape
        let pageHeight: CGFloat = 595
        let margin: CGFloat = 40
        let rowHeight: CGFloat = 18
        let headerHeight: CGFloat = 24
        let titleHeight: CGFloat = 30

        let colCount = headers.count
        let colWidth = (pageWidth - 2 * margin) / CGFloat(colCount)

        let pdfData = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return }

        var y = pageHeight - margin
        var currentPage = false

        func beginPage() {
            context.beginPDFPage(nil)
            y = pageHeight - margin
            currentPage = true
        }

        func endPage() {
            if currentPage {
                context.endPDFPage()
                currentPage = false
            }
        }

        func drawText(_ text: String, x: CGFloat, y: CGFloat, font: NSFont, color: NSColor = .black) {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: color
            ]
            let str = NSAttributedString(string: text, attributes: attrs)
            let line = CTLineCreateWithAttributedString(str)
            context.textPosition = CGPoint(x: x, y: y)
            CTLineDraw(line, context)
        }

        func drawHeaderRow() {
            // Header background
            context.setFillColor(NSColor.systemGray.withAlphaComponent(0.15).cgColor)
            context.fill(CGRect(x: margin, y: y - 4, width: pageWidth - 2 * margin, height: headerHeight))

            let font = NSFont.boldSystemFont(ofSize: 10)
            for (i, header) in headers.enumerated() {
                drawText(header, x: margin + CGFloat(i) * colWidth + 4, y: y + 4, font: font)
            }
            y -= headerHeight
        }

        // Start first page
        beginPage()

        // Title
        drawText(title, x: margin, y: y, font: NSFont.boldSystemFont(ofSize: 14))
        y -= titleHeight

        // Header
        drawHeaderRow()

        // Rows
        let bodyFont = NSFont.systemFont(ofSize: 9)
        for row in rows {
            if y < margin + rowHeight {
                endPage()
                beginPage()
                drawHeaderRow()
            }

            for (i, cell) in row.enumerated() {
                drawText(cell, x: margin + CGFloat(i) * colWidth + 4, y: y + 2, font: bodyFont)
            }
            y -= rowHeight
        }

        endPage()
        context.closePDF()

        try? pdfData.write(to: url, options: .atomic)
    }

    // MARK: - Export Format

    enum ExportFormat { case csv, pdf }

    // MARK: - Typed Exports

    static func exportTransactions(_ transactions: [Transaction], format: ExportFormat) {
        let headers = ["Date", "Status", "Description", "Code", "Amount"]
        let rows = transactions.map { txn in
            [txn.date, txn.status.symbol, txn.description, txn.code, txn.totalAmount]
        }
        directExport(baseName: "transactions", title: "Transactions", headers: headers, rows: rows, format: format)
    }

    static func exportReport(_ data: ReportData, format: ExportFormat) {
        let headers = ["Account"] + data.periodHeaders
        let rows = data.rows.map { row in
            [row.account] + row.amounts
        }
        directExport(baseName: data.title, title: data.title, headers: headers, rows: rows, format: format)
    }

    static func exportBudget(_ rows: [MergedBudgetRow], format: ExportFormat) {
        let headers = ["Account", "Budget", "Actual", "Remaining", "% Used"]
        let csvRows = rows.map { row in
            [
                row.rule.account,
                AmountFormatter.format(row.budget, commodity: row.commodity),
                AmountFormatter.format(row.actual, commodity: row.commodity),
                AmountFormatter.format(row.remaining, commodity: row.commodity),
                (row.usagePct / 100).formatted(.percent.precision(.fractionLength(0)))
            ]
        }
        directExport(baseName: "budget", title: "Budget", headers: headers, rows: csvRows, format: format)
    }

    // MARK: - Direct Export

    private static func directExport(baseName: String, title: String, headers: [String], rows: [[String]], format: ExportFormat) {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true

        switch format {
        case .csv:
            panel.nameFieldStringValue = "\(baseName).csv"
            panel.allowedContentTypes = [.commaSeparatedText]
        case .pdf:
            panel.nameFieldStringValue = "\(baseName).pdf"
            panel.allowedContentTypes = [.pdf]
        }

        guard panel.runModal() == .OK, let url = panel.url else { return }

        switch format {
        case .csv:
            var csv = headers.map { escapeCSV($0) }.joined(separator: ",") + "\n"
            for row in rows {
                csv += row.map { escapeCSV($0) }.joined(separator: ",") + "\n"
            }
            try? csv.write(to: url, atomically: true, encoding: .utf8)
        case .pdf:
            exportPDFDirect(url: url, title: title, headers: headers, rows: rows)
        }
    }

    private static func exportPDFDirect(url: URL, title: String, headers: [String], rows: [[String]]) {
        let pageWidth: CGFloat = 842
        let pageHeight: CGFloat = 595
        let margin: CGFloat = 40
        let rowHeight: CGFloat = 18
        let headerHeight: CGFloat = 24
        let titleHeight: CGFloat = 30
        let colWidth = (pageWidth - 2 * margin) / CGFloat(max(headers.count, 1))

        let pdfData = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return }

        var y = pageHeight - margin

        func beginPage() {
            context.beginPDFPage(nil)
            y = pageHeight - margin
        }

        func drawText(_ text: String, x: CGFloat, y: CGFloat, font: NSFont) {
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
            let str = NSAttributedString(string: text, attributes: attrs)
            let line = CTLineCreateWithAttributedString(str)
            context.textPosition = CGPoint(x: x, y: y)
            CTLineDraw(line, context)
        }

        func drawHeader() {
            context.setFillColor(NSColor.systemGray.withAlphaComponent(0.15).cgColor)
            context.fill(CGRect(x: margin, y: y - 4, width: pageWidth - 2 * margin, height: headerHeight))
            for (i, h) in headers.enumerated() {
                drawText(h, x: margin + CGFloat(i) * colWidth + 4, y: y + 4, font: .boldSystemFont(ofSize: 10))
            }
            y -= headerHeight
        }

        beginPage()
        drawText(title, x: margin, y: y, font: .boldSystemFont(ofSize: 14))
        y -= titleHeight
        drawHeader()

        for row in rows {
            if y < margin + rowHeight {
                context.endPDFPage()
                beginPage()
                drawHeader()
            }
            for (i, cell) in row.enumerated() {
                drawText(cell, x: margin + CGFloat(i) * colWidth + 4, y: y + 2, font: .systemFont(ofSize: 9))
            }
            y -= rowHeight
        }

        context.endPDFPage()
        context.closePDF()
        try? pdfData.write(to: url, options: .atomic)
    }

    private static func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}
