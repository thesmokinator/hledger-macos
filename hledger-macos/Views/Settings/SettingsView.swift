/// macOS Settings window with tabbed sections: Configuration, General, Investments, About.

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var journalPath = ""
    @State private var commodity = ""
    @State private var accountsView = "flat"
    @State private var hledgerPath = ""
    @State private var defaultSection = "summary"
    @State private var investmentsEnabled = false
    @State private var pricehistPath = ""
    @State private var tickerRows: [TickerRow] = []

    @State private var resolvedPath: String?
    @State private var isScanning = false
    @State private var saved = false

    @State private var selectedTab = "config"

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                tabButton("Configuration", icon: "gearshape", tag: "config")
                tabButton("General", icon: "slider.horizontal.3", tag: "general")
                tabButton("Investments", icon: "chart.line.uptrend.xyaxis", tag: "investments")
                tabButton("About", icon: "info.circle", tag: "about")
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            // Tab content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch selectedTab {
                    case "config": configTab
                    case "general": generalTab
                    case "investments": investmentsTab
                    case "about": aboutTab
                    default: configTab
                    }
                }
                .padding(24)
            }

            // Save / Cancel (not on About tab)
            if selectedTab != "about" {
                Divider()

                HStack {
                    if saved {
                        Text("Settings saved")
                            .font(.caption)
                            .foregroundStyle(.green)
                            .transition(.opacity)
                    }
                    Spacer()
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                    Button("Save") { save() }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
        }
        .frame(width: 560, height: 480)
        .onAppear { loadCurrent() }
        .onChange(of: journalPath) { updateResolvedPath() }
    }

    // MARK: - Tab Button

    private func tabButton(_ title: String, icon: String, tag: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 18))
            Text(title)
                .font(.caption)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .foregroundStyle(selectedTab == tag ? .primary : .secondary)
        .contentShape(Rectangle())
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(.quaternary.opacity(selectedTab == tag ? 0.5 : 0.001))
        }
        .onTapGesture { selectedTab = tag }
    }

    // MARK: - Configuration Tab

    private var configTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            settingsSection("Journal File") {
                HStack(spacing: 8) {
                    TextField("Path to file or directory", text: $journalPath)
                        .textFieldStyle(.roundedBorder)
                    Button("Browse...") { browseForJournal() }
                        .controlSize(.small)
                }

                if let resolved = resolvedPath {
                    Label(resolved, systemImage: "checkmark.circle")
                        .font(.caption).foregroundStyle(.green)
                } else if !journalPath.isEmpty {
                    Label("No journal file found at this path", systemImage: "xmark.circle")
                        .font(.caption).foregroundStyle(.red)
                }

                Text("Accepts .journal / .hledger / .j files, or a directory containing one.")
                    .font(.caption).foregroundStyle(.tertiary)
            }

            settingsSection("hledger Binary") {
                HStack(spacing: 8) {
                    TextField("Path to hledger (empty = auto-detect)", text: $hledgerPath)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        Task { await autoDetect() }
                    } label: {
                        HStack(spacing: 4) {
                            if isScanning { ProgressView().controlSize(.small) }
                            Text("Detect")
                        }
                    }
                    .controlSize(.small)
                    .disabled(isScanning)
                }

                if let path = appState.detectionResult?.hledgerPath {
                    Label("Detected: \(path)", systemImage: "checkmark.circle")
                        .font(.caption).foregroundStyle(.green)
                }
            }
        }
    }

    // MARK: - General Tab

    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            settingsSection("Preferences") {
                settingsRow("Default commodity") {
                    TextField("e.g. EUR", text: $commodity)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 150, alignment: .trailing)
                }

                settingsRow("Accounts view") {
                    Picker("", selection: $accountsView) {
                        Text("Flat").tag("flat")
                        Text("Tree").tag("tree")
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 150, alignment: .trailing)
                }

                settingsRow("Open on launch") {
                    Picker("", selection: $defaultSection) {
                        ForEach(NavigationSection.allCases) { section in
                            Text(section.label).tag(section.rawValue)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 150, alignment: .trailing)
                }
            }
        }
    }

    // MARK: - Investments Tab

    private var investmentsTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            settingsSection("Portfolio Tracking") {
                Toggle("Show investments section in Summary", isOn: $investmentsEnabled)
                    .font(.callout)
            }

            if investmentsEnabled {
                settingsSection("pricehist Binary") {
                    HStack(spacing: 8) {
                        TextField("Path to pricehist (pip install pricehist)", text: $pricehistPath)
                            .textFieldStyle(.roundedBorder)
                    }

                    if PriceService.isValid(path: pricehistPath) {
                        Label("Found", systemImage: "checkmark.circle")
                            .font(.caption).foregroundStyle(.green)
                    } else if !pricehistPath.isEmpty {
                        Label("Not found at this path", systemImage: "xmark.circle")
                            .font(.caption).foregroundStyle(.red)
                    } else {
                        Text("Required for market value fetching. Install with: pip install pricehist")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                settingsSection("Price Tickers") {
                    Text("Map journal commodities to Yahoo Finance tickers.")
                        .font(.caption).foregroundStyle(.secondary)

                    ForEach(Array(tickerRows.enumerated()), id: \.element.id) { index, _ in
                        HStack(spacing: 8) {
                            TextField("Commodity", text: $tickerRows[index].commodity)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                            Image(systemName: "arrow.right")
                                .font(.caption).foregroundStyle(.tertiary)
                            TextField("Yahoo ticker (e.g. XDWD.DE)", text: $tickerRows[index].ticker)
                                .textFieldStyle(.roundedBorder)
                            Button {
                                tickerRows.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle").foregroundStyle(.red)
                            }
                            .buttonStyle(.borderless)
                        }
                    }

                    Button {
                        tickerRows.append(TickerRow())
                    } label: {
                        Label("Add ticker", systemImage: "plus.circle").font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
    }

    // MARK: - About Tab

    private var aboutTab: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "text.book.closed")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("hledger-macos")
                .font(.title2.bold())

            Text("A native macOS companion for plain text accounting")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text("Version 1.0")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Text("Copyright \u{00A9} 2026 Michele Broggi")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Text("MIT License")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Divider().frame(width: 200)

            VStack(spacing: 6) {
                Text("Built with SwiftUI")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Powered by hledger CLI")
                    .font(.caption).foregroundStyle(.secondary)
            }

            VStack(spacing: 4) {
                Link("GitHub Repository", destination: URL(string: "https://github.com/thesmokinator/hledger-macos")!)
                    .font(.caption)
                Link("hledger.org", destination: URL(string: "https://hledger.org")!)
                    .font(.caption)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Layout Helpers

    private func settingsRow<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack {
            Text(label).font(.callout)
            Spacer()
            content()
        }
    }

    private func settingsSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Actions

    private func loadCurrent() {
        journalPath = appState.config.journalFilePath
        commodity = appState.config.defaultCommodity
        accountsView = appState.config.accountsViewMode
        hledgerPath = appState.config.hledgerBinaryPath
        defaultSection = appState.config.defaultSection
        investmentsEnabled = appState.config.investmentsEnabled
        pricehistPath = appState.config.pricehistBinaryPath
        tickerRows = appState.config.priceTickers.map { TickerRow(commodity: $0.key, ticker: $0.value) }
        if tickerRows.isEmpty { tickerRows.append(TickerRow()) }
        if hledgerPath.isEmpty, let detected = appState.detectionResult?.hledgerPath {
            hledgerPath = detected
        }
        updateResolvedPath()
    }

    private func updateResolvedPath() {
        if journalPath.isEmpty { resolvedPath = nil; return }
        resolvedPath = JournalFileResolver.resolve(configuredPath: journalPath)?.path
    }

    private func save() {
        appState.config.journalFilePath = journalPath
        appState.config.defaultCommodity = commodity
        appState.config.accountsViewMode = accountsView
        appState.config.hledgerBinaryPath = hledgerPath
        appState.config.defaultSection = defaultSection
        appState.config.investmentsEnabled = investmentsEnabled
        appState.config.pricehistBinaryPath = pricehistPath
        var tickers: [String: String] = [:]
        for row in tickerRows where !row.commodity.isEmpty && !row.ticker.isEmpty {
            tickers[row.commodity] = row.ticker
        }
        appState.config.priceTickers = tickers
        appState.setupBackend()
        Task { await appState.reload() }

        withAnimation { saved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { saved = false }
        }
    }

    private func autoDetect() async {
        isScanning = true
        hledgerPath = ""
        appState.config.hledgerBinaryPath = ""
        await appState.rescan()
        if let detected = appState.detectionResult?.hledgerPath { hledgerPath = detected }
        isScanning = false
    }

    private func browseForJournal() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.data]
        panel.message = "Select a journal file or a directory containing journal files"
        if panel.runModal() == .OK, let url = panel.url { journalPath = url.path }
    }
}

// MARK: - Ticker Row

struct TickerRow: Identifiable {
    let id = UUID()
    var commodity: String = ""
    var ticker: String = ""
}
