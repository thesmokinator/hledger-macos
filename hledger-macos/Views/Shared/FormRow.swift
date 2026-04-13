/// Shared form row layout used across all form dialogs.

import SwiftUI

struct FormRow<Content: View>: View {
    let label: String
    let content: Content
    var labelWidth: CGFloat = 90
    var required: Bool = false

    init(_ label: String, labelWidth: CGFloat = 90, required: Bool = false, @ViewBuilder content: () -> Content) {
        self.label = label
        self.labelWidth = labelWidth
        self.required = required
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            HStack(spacing: 2) {
                Text(label)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if required {
                    Text("*")
                        .font(.callout.bold())
                        .foregroundStyle(.red)
                }
            }
            .frame(width: labelWidth, alignment: .trailing)
            .padding(.top, Theme.Spacing.xsPlus)
            content
        }
    }
}
