# GitGlance — Native Android App

A native Android GitHub repository explorer. Browse files, preview code, export as .zip or .txt.

## Features
- 🔍 Search GitHub repos by `owner/repo` or full URL
- 📜 Instant history search — tap any past repo to reopen instantly
- 🌳 Expandable file tree with folder collapse/expand
- ☑️ Multi-select files with cascading folder checkboxes
- 👁️ File preview bottom sheet with monospace code view
- 🌿 Branch switcher
- 📦 Export selected files as `.zip` (saved to Downloads)
- 📄 Export selected files as `.txt` (concatenated, LLM-ready)
- 🔑 PAT token support for private repos & higher rate limits

## Setup

1. Open in **Android Studio** (Hedgehog or later)
2. Let Gradle sync
3. Run on an emulator or device (API 26+)

## PAT Token
For private repos or to avoid rate limits, tap the 🔑 icon and paste your GitHub Personal Access Token.
Generate one at: https://github.com/settings/tokens

## Architecture
- **Kotlin** + **Coroutines**
- **Retrofit2** — GitHub REST API
- **Room** — search history persistence
- **Material Design 3** — dark theme
- **ViewBinding** — type-safe layout access
