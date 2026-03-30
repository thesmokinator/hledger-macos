/// Placeholder for recurring transactions view (Phase 4).

import SwiftUI

struct RecurringView: View {
    var body: some View {
        ContentUnavailableView(
            "Recurring",
            systemImage: "repeat",
            description: Text("Recurring transactions coming in a future update.")
        )
        .navigationTitle("Recurring")
    }
}
