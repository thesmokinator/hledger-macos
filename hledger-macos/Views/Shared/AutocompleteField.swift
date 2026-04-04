/// Text field with native SwiftUI autocomplete suggestions.
/// Uses .textInputSuggestions for proper macOS integration without focus issues.

import SwiftUI

struct AutocompleteField: View {
    let placeholder: String
    @Binding var text: String
    let suggestions: [String]

    @State private var debouncedText = ""
    @State private var debounceTask: Task<Void, Never>?

    private var filtered: [String] {
        guard !debouncedText.isEmpty else { return [] }
        let query = debouncedText.lowercased()
        return suggestions.filter { $0.lowercased().contains(query) && $0 != text }.prefix(8).map { $0 }
    }

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.roundedBorder)
            .onChange(of: text) {
                debounceTask?.cancel()
                debounceTask = Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    if !Task.isCancelled {
                        debouncedText = text
                    }
                }
            }
            .textInputSuggestions {
                ForEach(filtered, id: \.self) { suggestion in
                    Text(suggestion)
                        .textInputCompletion(suggestion)
                }
            }
    }
}
