/// Text field with popover autocomplete suggestions.
/// Tab accepts the top suggestion (or the only one). Arrow keys + Enter to pick.

import SwiftUI

struct AutocompleteField: View {
    let placeholder: String
    @Binding var text: String
    let suggestions: [String]

    @State private var showSuggestions = false
    @State private var selectedIndex = 0
    @FocusState private var isFocused: Bool

    private var filtered: [String] {
        guard !text.isEmpty else { return [] }
        let query = text.lowercased()
        return suggestions.filter { $0.lowercased().contains(query) }.prefix(8).map { $0 }
    }

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.roundedBorder)
            .focused($isFocused)
            .onChange(of: text) {
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
                // Enter: accept selected suggestion if showing, otherwise just submit
                if showSuggestions && !filtered.isEmpty {
                    text = filtered[selectedIndex]
                }
                showSuggestions = false
            }
            .onKeyPress(.tab) {
                // Tab: accept suggestion if showing, then let focus advance
                if showSuggestions && !filtered.isEmpty {
                    text = filtered[selectedIndex]
                    showSuggestions = false
                }
                return .ignored // always let Tab advance focus
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
                            text = suggestion
                            showSuggestions = false
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
}
