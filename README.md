# Clipboard Library

> **"Copy once. Find it whenever you need it."**

A lightweight, native macOS clipboard manager built with SwiftUI and SwiftData. Designed for privacy, speed, and seamless daily workflow.

---

## Installation

1. Download **`ClipboardLibrary.dmg`** from the [Releases](https://github.com/) page.
2. Open the downloaded `.dmg` file.
3. Drag **Clipboard Library** into your **Applications** folder.
4. Launch **Clipboard Library** from Applications or Spotlight.

> **Note on First Launch (Gatekeeper):**
> If you encounter an "Unidentified Developer" warning on first launch (prior to Apple Notarization), right-click (or Control-click) `Clipboard Library.app` in `/Applications` and select **Open**, then click **Open** in the confirmation dialog.

---

## First Launch Setup

- **Menu Bar Utility:** Clipboard Library lives directly in your macOS menu bar (clipboard icon) for instant access.
- **Clipboard Monitoring:** By default, Clipboard Library monitors the system pasteboard locally. You can pause or resume monitoring anytime in Settings.
- **Global Shortcut & Auto-Paste Permissions:**
  - To enable global keyboard shortcuts that auto-paste saved clips into frontmost applications, grant **Accessibility** permissions when prompted, or navigate to:
    `System Settings → Privacy & Security → Accessibility` and toggle **Clipboard Library** ON.
  - If Accessibility permission is not granted, triggering a favorite shortcut safely copies the text to the clipboard without auto-pasting.
- **100% Local Privacy:** Clipboard Library requires no login, connects to no remote servers, and stores all text clippings locally on your Mac using SwiftData.

---

## Basic Usage

- **Copy Text Normally:** Any text copied in any application is automatically captured into your Library.
- **Access from Menu Bar:** Click the menu bar icon or press `⌘1` to open the Library, `⌘2` for Favorites, `⌘,` for Settings, and `⌘Q` to Quit.
- **Search History:** Use the live search bar at the top of the Library to quickly filter clips.
- **Favorite Frequently Used Clips:** Click the ⭐ star button next to any item to pin it to Favorites. Favorites are immune to history cleanup.
- **Assign Global Hotkeys:** In Favorites, click **Assign Shortcut** on any item to record a custom global hotkey combination.
- **Inspect Large Content:** Click any clipboard row to open a full, scrollable detail view preserving indentation, line breaks, and metadata.
- **Browse Previous Dates:** Select the **Calendar** tab in the sidebar to review clipboard entries from past days.
- **History Retention & Cleanup:** Clean up your history safely from Settings or the Library menu (Today, Yesterday, This Week, This Month, Last 90 Days, or Clear All). Your Favorites are always protected.

---

## Privacy & Security

- 🔒 **Local Storage Only:** Clipboard history is stored locally in macOS Application Support via SwiftData.
- 🚫 **No Accounts or Cloud Sync:** No external logins, user accounts, or cloud databases.
- 🚫 **Zero Analytics / Telemetry:** No tracking, telemetry, or network activity.
- 🛡️ **Hardened Runtime:** Compiled with Apple Hardened Runtime for process integrity.

---

## Building from Source

### Prerequisites
- macOS 14.0 (Sonoma) or newer
- Xcode 16.0 or newer

### Build & Package DMG
```bash
# Clone the repository
git clone https://github.com/<your-username>/ClipboardLibrary.git
cd ClipboardLibrary

# Build Release application and generate DMG
./scripts/build_release.sh
```
The output `.dmg` and `.zip` will be generated in `dist/`.

---

## License
MIT License. Free and open source for personal and commercial use.
