/// Structured date input with YYYY-MM-DD validation.
/// Reusable across Transaction, Recurring, and other forms.

import SwiftUI

struct DateInputField: View {
    @Binding var year: String
    @Binding var month: String
    @Binding var day: String
    var optional: Bool = false

    @FocusState private var focused: Field?
    @State private var skipAdvance = true

    private enum Field { case year, month, day }

    var dateString: String {
        guard !year.isEmpty || !month.isEmpty || !day.isEmpty else { return "" }
        return "\(year)-\(month)-\(day)"
    }

    var isValid: Bool {
        if optional && year.isEmpty && month.isEmpty && day.isEmpty { return true }
        guard year.count == 4, month.count == 2, day.count == 2 else { return false }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: dateString) != nil
    }

    private var showIndicator: Bool {
        !year.isEmpty || !month.isEmpty || !day.isEmpty
    }

    var body: some View {
        HStack(spacing: 4) {
            TextField("YYYY", text: $year)
                .textFieldStyle(.roundedBorder)
                .frame(width: 60)
                .focused($focused, equals: .year)
                .accessibilityLabel("Year")
                .onChange(of: year) { guard !skipAdvance else { return }; filter(&year, max: 4) { focused = .month } }

            Text("-").foregroundStyle(.secondary)

            TextField("MM", text: $month)
                .textFieldStyle(.roundedBorder)
                .frame(width: 40)
                .focused($focused, equals: .month)
                .accessibilityLabel("Month")
                .onChange(of: month) { guard !skipAdvance else { return }; filter(&month, max: 2) { focused = .day } }

            Text("-").foregroundStyle(.secondary)

            TextField("DD", text: $day)
                .textFieldStyle(.roundedBorder)
                .frame(width: 40)
                .focused($focused, equals: .day)
                .accessibilityLabel("Day")
                .onChange(of: day) { guard !skipAdvance else { return }; filter(&day, max: 2, advance: nil) }

            if showIndicator {
                Image(systemName: isValid ? "checkmark.circle" : "xmark.circle")
                    .foregroundStyle(isValid ? .green : .red)
                    .font(.caption)
                    .accessibilityLabel(isValid ? "Valid date" : "Invalid date")
            }

            Spacer()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                skipAdvance = false
            }
        }
    }

    private func filter(_ value: inout String, max: Int, advance: (() -> Void)? = nil) {
        value = String(value.filter(\.isNumber).prefix(max))
        if value.count == max { advance?() }
    }
}
