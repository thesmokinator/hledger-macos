/// Placeholder for budget view (Phase 4).

import SwiftUI

struct BudgetView: View {
    var body: some View {
        ContentUnavailableView(
            "Budget",
            systemImage: "chart.bar",
            description: Text("Budget tracking coming in a future update.")
        )
        .navigationTitle("Budget")
    }
}
