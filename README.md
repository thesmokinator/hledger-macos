# hledger for Mac

A native macOS app for [hledger](https://hledger.org) plain-text accounting. Manage transactions, view summaries, track investments, and navigate your journal — all from a native SwiftUI interface.

Built with Swift and SwiftUI. Companion to [hledger-textual](https://github.com/thesmokinator/hledger-textual) (terminal UI).

## Stack

- **Swift 5 / SwiftUI** - native macOS UI
- **hledger** - plain-text accounting CLI (must be installed separately)
- **Xcode 26+** - build system

## Requirements

- macOS 26+
- [hledger](https://hledger.org/install.html) installed (`brew install hledger`)

## Features

- **Summary dashboard** - income/expenses/net with saving rate, expense and income breakdowns, liabilities overview
- **Transaction management** - list, create, edit, clone, delete transactions with full journal support
- **Account browser** - flat and tree views with locale-formatted balances
- **Investment tracking** - portfolio positions, book values, and market prices via pricehist
- **Smart search** - hledger query syntax with suggestions (`desc:`, `acct:`, `amt:`, `tag:`, `status:`)
- **Journal routing** - auto-detects glob (`YYYY/*.journal`), flat (`YYYY-MM.journal`), or single-file journal structure
- **Keyboard shortcuts** - Cmd+1-6 sections, Cmd+N new transaction, Cmd+E edit, Cmd+T current month, arrow keys for navigation
- **Locale-aware formatting** - amounts displayed with system locale (e.g. `€1.234,56` in it_IT)

## Journal File Resolution

The journal file is resolved in this order:

1. Path configured in Settings
2. `LEDGER_FILE` environment variable
3. `~/.hledger.journal`

Accepts a file path or a directory containing journal files (auto-detects `main.journal`).

## Examples

The [`examples/`](examples/) directory contains sample journals to get started:

| Example | Description |
|---------|-------------|
| [`hledger-simple/`](examples/hledger-simple/) | Single-file hledger journal with basic transactions |
| [`hledger-multi-file/`](examples/hledger-multi-file/) | Multi-file journal with `include YYYY/*.journal` glob routing and investments |

To try an example, point Settings > Journal File to the example directory or its `main.journal` file.

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
| Tab | Select first transaction |
| Left/Right arrows | Navigate months (in Transactions) |
| Up/Down arrows | Navigate transaction list |

## Architecture

```
Backend/
  AccountingBackend.swift     Protocol: the contract for any backend
  HledgerBackend.swift        hledger CLI implementation
  SubprocessRunner.swift      Async Process wrapper
  JournalWriter.swift         Append/replace/delete with backup+validate
  TransactionFormatter.swift  Transaction → journal text
  BinaryDetector.swift        CLI binary detection
  JournalFileResolver.swift   Journal file resolution chain

Models/                       Transaction, Posting, Amount, AccountNode, etc.
Services/                     AppState, PriceService
Config/                       AppConfig, AmountFormatter, AmountParser
Views/                        SwiftUI views organized by section
```

The backend is abstracted behind the `AccountingBackend` protocol, making the architecture extensible.

## Development

```bash
git clone https://github.com/thesmokinator/hledger-macos.git
cd hledger-macos
open hledger-macos.xcodeproj
```

Build and run with Xcode (Cmd+R).
