# GitGlance — Flutter Android App

A native Android reimplementation of the GitGlance web app. Browse GitHub repositories, preview files with syntax highlighting, and export selected files as `.zip` or `.txt`.

## Features

- 🔍 **Search repos** by `owner/repo` or full GitHub URL
- 🌿 **Branch switching** with dropdown
- 📁 **File tree** with folder expand/collapse and per-file/folder checkboxes
- 👁 **File preview** with syntax highlighting (40+ languages)
- 📦 **Export to ZIP** — saves to device via share sheet
- 📄 **Export to TXT** — all files concatenated with separators
- 🔑 **Multi-PAT management** — store multiple tokens securely (AES-256 encrypted)
- 📚 **Repo history** — last 30 repos saved locally, sorted by recency
- ⚡ **Content caching** — files cached in memory per session

## Setup

### Prerequisites
- Flutter 3.22+
- Java 17+
- Android Studio or VS Code with Flutter extension

### Local build
```bash
flutter pub get
flutter run
```

### Via GitHub Actions
Push to `main` — the workflow builds a debug APK automatically.
Download it from the Actions tab → Artifacts.

## PAT Token
For private repos and higher rate limits (5,000 req/hr vs 60/hr):
1. Go to **github.com/settings/tokens**
2. Generate a classic token with `repo` scope
3. In the app, tap the key icon → **Save Token**

Tokens are stored using Android's `EncryptedSharedPreferences` (AES-256).

## Font (optional)
The app references JetBrains Mono for code. To enable it:
1. Download from [jetbrains.com/lp/mono](https://www.jetbrains.com/lp/mono/)
2. Place `.ttf` files in `assets/fonts/`
3. Run `flutter pub get`

Without the font files, Flutter falls back to the system monospace font.
