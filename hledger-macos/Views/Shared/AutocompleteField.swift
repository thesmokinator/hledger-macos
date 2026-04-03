/// Text field with popover autocomplete suggestions.

import SwiftUI

struct AutocompleteField: View {
    let placeholder: String
    @Binding var text: String
    let suggestions: [String]

    @State private var showSuggestions = false
    @State private var selectedIndex = 0
    @State private var justAccepted = false
    @FocusState private var isFocused: Bool

    private var filtered: [String] {
        guard !text.isEmpty else { return [] }
        let query = text.lowercased()
        return suggestions.filter { $0.lowercased().contains(query) && $0 != text }.prefix(8).map { $0 }
    }

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.roundedBorder)
            .focused($isFocused)
            .onChange(of: text) {
                if justAccepted {
                    justAccepted = false
                    return
                }
                selectedIndex = 0
                showSuggestions = isFocused && !filtered.isEmpty
            }
            .onChange(of: isFocused) {
                if !isFocused {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        showSuggestions = false
                    }
                }
            }
            .onSubmit {
                if showSuggestions && !filtered.isEmpty {
                    acceptSuggestion(filtered[selectedIndex])
                }
                showSuggestions = false
            }
            .onKeyPress(.tab) {
                if showSuggestions && !filtered.isEmpty {
                    acceptSuggestion(filtered[selectedIndex])
                }
                return .ignored
            }
            .onKeyPress(.downArrow) {
                if showSuggestions && selectedIndex < filtered.count - 1 {
                    selectedIndex += 1
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(.upArrow) {
                if showSuggestions && selectedIndex > 0 {
                    selectedIndex -= 1
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(.escape) {
                if showSuggestions {
                    showSuggestions = false
                    return .handled
                }
                return .ignored
            }
            .popover(isPresented: $showSuggestions, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(filtered.enumerated()), id: \.element) { index, suggestion in
                        Button {
                            acceptSuggestion(suggestion)
                        } label: {
                            Text(suggestion)
                                .font(.callout)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .contentShape(Rectangle())
                                .background(index == selectedIndex ? Color.accentColor.opacity(0.2) : Color.clear)
                        }
                        .buttonStyle(.plain)

                        if index < filtered.count - 1 {
                            Divider()
                        }
                    }
                }
                .frame(width: 280)
                .padding(.vertical, 4)
            }
    }

    private func acceptSuggestion(_ suggestion: String) {
        justAccepted = true
        text = suggestion
        showSuggestions = false
    }
}
