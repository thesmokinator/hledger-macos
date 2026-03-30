# hledger-macos

A native macOS companion app for [hledger](https://hledger.org) plain-text accounting. Manage transactions, view summaries, track investments, and navigate your journal — all from a native SwiftUI interface.

Built with Swift and SwiftUI. Companion to [hledger-textual](https://github.com/thesmokinator/hledger-textual) (terminal UI).

## Stack

- **Swift 5 / SwiftUI** - native macOS UI
- **hledger** - plain-text accounting CLI (must be installed separately)
- **Xcode 26+** - build system

## Requirements

- macOS 26+
- [hledger](https://hledger.org/install.html) installed (`brew install hledger`)

## Features

- **Summary dashboard** - monthly income/expenses/net with saving rate, expense and income breakdowns, liabilities overview
- **Transaction management** - list, create, edit, clone, delete transactions with full hledger journal support
- **Account browser** - flat and tree views with balances
- **Investment tracking** - portfolio positions, book values, and market prices via pricehist
- **Smart search** - hledger query syntax with suggestions (`desc:`, `acct:`, `amt:`, `tag:`, `status:`)
- **Journal routing** - auto-detects glob (`YYYY/*.journal`), flat (`YYYY-MM.journal`), or single-file journal structure
- **Keyboard shortcuts** - Cmd+1-6 sections, Cmd+N new transaction, Cmd+E edit, Cmd+T current month, arrow keys for navigation

## Journal File Resolution

The journal file is resolved in this order:

1. Path configured in Settings
2. `LEDGER_FILE` environment variable
3. `~/.hledger.journal`

Accepts a file path (`.journal`, `.hledger`, `.j`) or a directory containing journal files (auto-detects `main.journal`).

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Cmd+1 - Cmd+6 | Switch section (Summary, Transactions, Recurring, Budget, Reports, Accounts) |
| Cmd+N | New transaction |
| Cmd+E | Edit selected transaction |
| Cmd+D | Clone transaction |
| Cmd+T | Go to current month |
| Cmd+R | Reload data |
| Cmd+F | Focus search |
| Cmd+, | Settings |
| Cmd+/ | Keyboard shortcuts panel |
| Left/Right arrows | Navigate months (in Transactions) |

## Development

```bash
git clone https://github.com/thesmokinator/hledger-macos.git
cd hledger-macos
open hledger-macos.xcodeproj
```

Build and run with Xcode (Cmd+R).
