import XCTest

final class hledger_macosUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    /// Captures screenshots of all main sections for documentation.
    @MainActor
    func testCaptureAllSections() throws {
        let app = XCUIApplication()
        app.launch()

        // Wait for app to initialize
        sleep(3)

        let sidebar = app.outlines.firstMatch

        // Summary
        captureScreenshot(named: "01-summary")

        // Transactions
        if sidebar.cells.containing(.staticText, identifier: "Transactions").firstMatch.exists {
            sidebar.cells.containing(.staticText, identifier: "Transactions").firstMatch.click()
            sleep(2)
            captureScreenshot(named: "02-transactions")
        }

        // Recurring
        if sidebar.cells.containing(.staticText, identifier: "Recurring").firstMatch.exists {
            sidebar.cells.containing(.staticText, identifier: "Recurring").firstMatch.click()
            sleep(2)
            captureScreenshot(named: "03-recurring")
        }

        // Budget
        if sidebar.cells.containing(.staticText, identifier: "Budget").firstMatch.exists {
            sidebar.cells.containing(.staticText, identifier: "Budget").firstMatch.click()
            sleep(2)
            captureScreenshot(named: "04-budget")
        }

        // Reports
        if sidebar.cells.containing(.staticText, identifier: "Reports").firstMatch.exists {
            sidebar.cells.containing(.staticText, identifier: "Reports").firstMatch.click()
            sleep(2)
            captureScreenshot(named: "05-reports")
        }

        // Accounts
        if sidebar.cells.containing(.staticText, identifier: "Accounts").firstMatch.exists {
            sidebar.cells.containing(.staticText, identifier: "Accounts").firstMatch.click()
            sleep(2)
            captureScreenshot(named: "06-accounts")
        }
    }

    private func captureScreenshot(named name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
