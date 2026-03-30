/// Placeholder for reports view (Phase 3).

import SwiftUI

struct ReportsView: View {
    var body: some View {
        ContentUnavailableView(
            "Reports",
            systemImage: "doc.text.magnifyingglass",
            description: Text("Financial reports coming in a future update.")
        )
        .navigationTitle("Reports")
    }
}
