/// Onboarding view shown when hledger CLI is not found.

import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var showAdvanced = false
    @State private var customHledgerPath = ""
    @State private var customJournalPath = ""
    @State private var isScanning = false

    private var isFound: Bool {
        appState.detectionResult?.isFound == true
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon
            Image(systemName: "text.book.closed")
                .font(.system(size: 56))
                .foregroundColor(.accentColor)
                .padding(.bottom, 20)

            // Title
            Text("Welcome to hledger")
                .font(.largeTitle.bold())
                .padding(.bottom, 6)

            // Subtitle
            Text("A macOS companion for plain text accounting")
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.bottom, 32)

            // Status row
            HStack(spacing: 10) {
                Image(systemName: isFound ? "checkmark.circle.fill" : "xmark.circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isFound ? .green : .red)

                VStack(alignment: .leading, spacing: 1) {
                    Text("hledger cli")
                        .font(.subheadline.weight(.medium))

                    if let path = appState.detectionResult?.hledgerPath {
                        Text(path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Not found \u{2014} install with `brew install hledger`")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
            .frame(maxWidth: 440)
            .padding(.bottom, 12)

            // Advanced settings
            VStack(spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showAdvanced.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .rotationEffect(.degrees(showAdvanced ? 90 : 0))
                        Text("Advanced settings")
                            .font(.subheadline)
                        Spacer()
                    }
                    .foregroundStyle(.secondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)

                if showAdvanced {
                    VStack(spacing: 10) {
                        LabeledField(label: "hledger path", text: $customHledgerPath, placeholder: "/opt/homebrew/bin/hledger")
                        LabeledField(label: "Journal file", text: $customJournalPath, placeholder: "~/.hledger.journal")
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
            .frame(maxWidth: 440)

            Spacer()

            // Buttons
            HStack(spacing: 12) {
                Button {
                    Task { await checkAgain() }
                } label: {
                    HStack(spacing: 4) {
                        if isScanning {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("Check again")
                    }
                    .frame(minWidth: 90)
                }
                .disabled(isScanning)

                Button("Continue") {
                    Task { await continueSetup() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isScanning || !isFound)
            }
            .padding(.bottom, 8)

            if let error = appState.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .padding(.bottom, 4)
            }

            Spacer()
                .frame(height: 40)
        }
        .padding(.horizontal, 40)
        .frame(minWidth: 560, minHeight: 480)
        .onAppear {
            customHledgerPath = appState.config.hledgerBinaryPath
            customJournalPath = appState.config.journalFilePath
            if customHledgerPath.isEmpty, let detected = appState.detectionResult?.hledgerPath {
                customHledgerPath = detected
            }
            if customJournalPath.isEmpty {
                let defaultPath = JournalFileResolver.defaultPath()
                if !defaultPath.isEmpty { customJournalPath = defaultPath }
            }
        }
    }

    private func checkAgain() async {
        isScanning = true
        applyCustomPaths()
        await appState.rescan()
        // Update fields if detection found something new
        if let detected = appState.detectionResult?.hledgerPath, customHledgerPath.isEmpty {
            customHledgerPath = detected
        }
        isScanning = false
    }

    private func continueSetup() async {
        isScanning = true
        applyCustomPaths()
        await appState.rescan()
        isScanning = false
        if appState.detectionResult?.isFound != true {
            appState.errorMessage = "hledger not found. Please install it or specify the path."
        }
    }

    private func applyCustomPaths() {
        appState.config.hledgerBinaryPath = customHledgerPath
        appState.config.journalFilePath = customJournalPath
    }
}

// MARK: - Labeled Field

private struct LabeledField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .trailing)
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .font(.callout)
        }
    }
}
