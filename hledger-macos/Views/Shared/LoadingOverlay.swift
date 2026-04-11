/// Centered loading indicator with a message that fills available space.
/// Replaces the Spacer / ProgressView / Spacer pattern duplicated across views.

import SwiftUI

struct LoadingOverlay: View {
    let message: String

    var body: some View {
        VStack {
            Spacer()
            ProgressView(message)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
