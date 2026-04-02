/// Shared form row layout used across all form dialogs.

import SwiftUI

struct FormRow<Content: View>: View {
    let label: String
    let content: Content
    var labelWidth: CGFloat = 90

    init(_ label: String, labelWidth: CGFloat = 90, @ViewBuilder content: () -> Content) {
        self.label = label
        self.labelWidth = labelWidth
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: labelWidth, alignment: .trailing)
                .padding(.top, 6)
            content
        }
    }
}
