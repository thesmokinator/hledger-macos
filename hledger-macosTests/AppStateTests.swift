import Testing
import Foundation
@testable import hledger_for_Mac

// MARK: - Mock Types

struct MockBinaryDetector: BinaryDetecting {
    let result: BinaryDetectionResult

    func detect(customHledgerPath: String) -> BinaryDetectionResult {
        result
    }
}

struct MockJournalResolver: JournalResolving {
    let url: URL?

    func resolve(configuredPath: String, shellDetectedPath: String?) -> URL? {
        url
    }
}

// MARK: - AppState.detectAndSetup Tests

@Suite("AppState.detectAndSetup")
struct AppStateDetectAndSetupTests {

    @Test @MainActor
    func binaryFoundAndJournalFound() {
        let detector = MockBinaryDetector(
            result: BinaryDetectionResult(
                hledgerPath: "/usr/local/bin/hledger",
                detectedJournalPath: "/tmp/test.journal"
            )
        )
        let resolver = MockJournalResolver(url: URL(fileURLWithPath: "/tmp/test.journal"))
        let state = AppState(binaryDetector: detector, journalResolver: resolver)

        let ready = state.detectAndSetup()

        #expect(ready == true)
        #expect(state.isInitialized == true)
        #expect(state.activeBackend != nil)
        #expect(state.errorMessage == nil)
    }

    @Test @MainActor
    func binaryFoundButNoJournal() {
        let detector = MockBinaryDetector(
            result: BinaryDetectionResult(
                hledgerPath: "/usr/local/bin/hledger",
                detectedJournalPath: nil
            )
        )
        let resolver = MockJournalResolver(url: nil)
        let state = AppState(binaryDetector: detector, journalResolver: resolver)

        let ready = state.detectAndSetup()

        #expect(ready == false)
        #expect(state.isInitialized == false)
        #expect(state.activeBackend == nil)
        #expect(state.errorMessage != nil)
    }

    @Test @MainActor
    func binaryNotFound() {
        let detector = MockBinaryDetector(
            result: BinaryDetectionResult(
                hledgerPath: nil,
                detectedJournalPath: nil
            )
        )
        let resolver = MockJournalResolver(url: nil)
        let state = AppState(binaryDetector: detector, journalResolver: resolver)

        let ready = state.detectAndSetup()

        #expect(ready == false)
        #expect(state.isInitialized == false)
        #expect(state.activeBackend == nil)
        #expect(state.detectionResult?.isFound == false)
    }
}
