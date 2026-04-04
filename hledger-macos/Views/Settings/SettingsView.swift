/// macOS Settings window — inspired by native macOS System Settings.
/// Uses TabView with native macOS tab styling for a polished, familiar feel.

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
    @State private var appearance = "system"
    @State private var customCommodity = ""
    @State private var treeExpanded = false
    @State private var barChartMode = "dynamic"
    @State private var investmentsEnabled = false
    @State private var pricehistPath = ""
    @State private var tickerRows: [TickerRow] = []
    @State private var aiEnabled = false

    @State private var resolvedPath: String?
    @State private var isScanning = false
    @State private var saved = false
    @State private var showReloadAlert = false
    @State private var originalJournalPath = ""

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }

            pathsTab
                .tabItem { Label("Paths", systemImage: "folder") }

            investmentsTab
                .tabItem { Label("Investments", systemImage: "chart.line.uptrend.xyaxis") }

            aiTab
                .tabItem { Label("AI Assistant", systemImage: "sparkles") }

            aboutTab
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 520, height: 420)
        .onAppear { loadCurrent() }
        .onChange(of: journalPath) { updateResolvedPath() }
        .alert("Journal file changed", isPresented: $showReloadAlert) {
            Button("Reload") { performSave() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("The journal file path has changed. All data will be reloaded from the new file.")
        }
    }

    // MARK: - General Tab

    private var generalTab: some View {
        VStack(spacing: 0) {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $appearance) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }

                    Picker("Default commodity", selection: $commodity) {
                        Text("€").tag("€")
                        Text("$").tag("$")
                        Text("£").tag("£")
                        Text("EUR").tag("EUR")
                        Text("USD").tag("USD")
                        Text("GBP").tag("GBP")
                        Divider()
                        Text("Custom...").tag("__custom__")
                    }

                    if commodity == "__custom__" || !["€", "$", "£", "EUR", "USD", "GBP"].contains(commodity) {
                        TextField("", text: $customCommodity, prompt: Text("CHF, SEK, BTC..."))
                            .multilineTextAlignment(.trailing)
                            .onSubmit { commodity = customCommodity }
                            .onChange(of: customCommodity) { commodity = customCommodity }
                    }

                    Picker("Accounts view", selection: $accountsView) {
                        Text("Flat").tag("flat")
                        Text("Tree").tag("tree")
                    }

                    if accountsView == "tree" {
                        Toggle("Expand tree by default", isOn: $treeExpanded)
                    }

                    Picker("Bar charts", selection: $barChartMode) {
                        Text("Dynamic").tag("dynamic")
                        Text("Fixed width").tag("fixed")
                    }
                }

                Section("Startup") {
                    Picker("Open on launch", selection: $defaultSection) {
                        ForEach(NavigationSection.allCases) { section in
                            Text(section.label).tag(section.rawValue)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            saveBar
        }
    }

    // MARK: - Paths Tab

    private var pathsTab: some View {
        VStack(spacing: 0) {
            Form {
                Section("Journal File") {
                    HStack {
                        TextField("Path to journal file or directory", text: $journalPath)
                        Button("Browse...") { browseForJournal() }
                            .controlSize(.small)
                    }

                    if let resolved = resolvedPath {
                        Label(resolved, systemImage: "checkmark.circle")
                            .foregroundStyle(.green)
                            .font(.caption)
                    } else if !journalPath.isEmpty {
                        Label("No journal file found at this path", systemImage: "xmark.circle")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                    Text("Accepts .journal / .hledger / .j files, or a directory containing one.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Section("hledger Binary") {
                    HStack {
                        TextField("Path (empty = auto-detect)", text: $hledgerPath)
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
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                }
            }
            .formStyle(.grouped)

            saveBar
        }
    }

    // MARK: - Investments Tab

    private var investmentsTab: some View {
        VStack(spacing: 0) {
            Form {
                Section("Portfolio") {
                    Toggle("Show investments in Summary", isOn: $investmentsEnabled)
                }

                if investmentsEnabled {
                    Section("pricehist") {
                        TextField("Path to pricehist binary", text: $pricehistPath)

                        if PriceService.isValid(path: pricehistPath) {
                            Label("Found", systemImage: "checkmark.circle")
                                .foregroundStyle(.green)
                                .font(.caption)
                        } else if !pricehistPath.isEmpty {
                            Label("Not found at this path", systemImage: "xmark.circle")
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                        Text("Required for market values. Install: pipx install pricehist (or pip install pricehist)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    Section("Price Tickers") {
                        ForEach(Array(tickerRows.enumerated()), id: \.element.id) { index, _ in
                            LabeledContent {
                                HStack {
                                    TextField("", text: $tickerRows[index].ticker, prompt: Text("Yahoo ticker"))
                                    if tickerRows.count > 1 {
                                        Button {
                                            tickerRows.remove(at: index)
                                        } label: {
                                            Image(systemName: "minus.circle")
                                                .foregroundStyle(.red)
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                }
                            } label: {
                                TextField("", text: $tickerRows[index].commodity, prompt: Text("Ticker"))
                                    .frame(width: 80)
                            }
                        }

                        Button {
                            tickerRows.append(TickerRow())
                        } label: {
                            Label("Add Ticker", systemImage: "plus")
                        }

                        Text("Find tickers at finance.yahoo.com")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .formStyle(.grouped)

            saveBar
        }
    }

    // MARK: - AI Tab

    private var aiTab: some View {
        VStack(spacing: 0) {
            Form {
                Section("AI Assistant") {
                    Toggle("Enable AI Assistant", isOn: $aiEnabled)

                    if aiEnabled {
                        if AppleFoundationModelProvider.isAvailable {
                            Label("Using Apple Intelligence (built-in)", systemImage: "checkmark.circle")
                                .foregroundStyle(.green)
                                .font(.caption)
                        } else {
                            Label("Apple Intelligence is not available on this device", systemImage: "xmark.circle")
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                    }
                }

                Section("Privacy") {
                    Label {
                        Text("All processing happens locally on your Mac using Apple Intelligence. No financial data is sent to external servers.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "lock.shield")
                            .foregroundStyle(.green)
                    }
                }

                Section("Usage") {
                    Text("When enabled, an AI button appears at the bottom-left of the main window. You can also press \u{2318}\u{21E7}A to toggle the assistant.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("The assistant can answer questions about your journal: account balances, spending patterns, transaction summaries, and more.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            saveBar
        }
    }

    // MARK: - About Tab

    private var aboutTab: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            Text("hledger for Mac")
                .font(.title2.bold())

            Text("A native macOS companion for plain text accounting")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev")").foregroundStyle(.tertiary)
                Text("MIT License").foregroundStyle(.tertiary)
            }
            .font(.caption)

            Text("\u{00A9} 2026 Michele Broggi")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Divider().frame(width: 180).padding(.vertical, 4)

            HStack(spacing: 16) {
                Link("GitHub", destination: URL(string: "https://github.com/thesmokinator/hledger-macos")!)
                Link("hledger.org", destination: URL(string: "https://hledger.org")!)
            }
            .font(.callout)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Save Bar

    private var saveBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                if saved {
                    Text("Saved")
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
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Actions

    private func loadCurrent() {
        journalPath = appState.config.journalFilePath
        originalJournalPath = journalPath
        let savedCommodity = appState.config.defaultCommodity
        if ["€", "$", "£", "EUR", "USD", "GBP"].contains(savedCommodity) {
            commodity = savedCommodity
        } else {
            commodity = savedCommodity
            customCommodity = savedCommodity
        }
        accountsView = appState.config.accountsViewMode
        treeExpanded = appState.config.accountsTreeExpanded
        hledgerPath = appState.config.hledgerBinaryPath
        defaultSection = appState.config.defaultSection
        appearance = appState.config.appearance
        barChartMode = appState.config.barChartMode
        investmentsEnabled = appState.config.investmentsEnabled
        aiEnabled = appState.config.aiEnabled
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
        if journalPath != originalJournalPath {
            showReloadAlert = true
        } else {
            performSave()
        }
    }

    private func performSave() {
        appState.config.journalFilePath = journalPath
        appState.config.defaultCommodity = commodity
        appState.config.accountsViewMode = accountsView
        appState.config.accountsTreeExpanded = treeExpanded
        appState.config.hledgerBinaryPath = hledgerPath
        appState.config.defaultSection = defaultSection
        appState.config.appearance = appearance
        // Apply theme immediately
        switch appearance {
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        default: NSApp.appearance = nil
        }
        appState.config.barChartMode = barChartMode
        appState.config.investmentsEnabled = investmentsEnabled
        appState.config.aiEnabled = aiEnabled
        appState.config.pricehistBinaryPath = pricehistPath
        var tickers: [String: String] = [:]
        for row in tickerRows where !row.commodity.isEmpty && !row.ticker.isEmpty {
            tickers[row.commodity] = row.ticker
        }
        if tickers != appState.config.priceTickers {
            PriceService.invalidateCache()
        }
        appState.config.priceTickers = tickers
        appState.setupBackend()
        Task { await appState.reload() }
        originalJournalPath = journalPath

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
        panel.message = "Select a journal file or directory"
        if panel.runModal() == .OK, let url = panel.url { journalPath = url.path }
    }
}

struct TickerRow: Identifiable {
    let id = UUID()
    var commodity: String = ""
    var ticker: String = ""
}
