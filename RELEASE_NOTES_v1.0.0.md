# Clipboard Library v1.0.0 — Release Notes

**Release:** `v1.0.0`  
**Build:** `1`  
**Compatibility:** macOS 14.0 (Sonoma) or newer  
**Architecture:** Universal Binary (Apple Silicon `arm64` + Intel `x86_64`)  

---

### What's Included

- **Native macOS Interface:** Sleek, modern SwiftUI experience with dark/light mode support, SF Symbols, responsive hover states, and smooth navigation.
- **Background Clipboard Capture:** Automatically captures copied plain-text clippings into Today's feed with duplicate suppression (< 1.2s debounce).
- **Menu Bar Companion:** Quick-access menu bar utility with shortcuts for Library (`⌘1`), Favorites (`⌘2`), Settings (`⌘,`), and Quit (`⌘Q`).
- **Favorites & Global Shortcuts:** Star frequently used clips and assign custom system-wide keyboard shortcuts. Triggering a shortcut pastes the item into whichever app is active.
- **Calendar History Browsing:** Filter and explore clipboard history by date with a single-click "Today" reset.
- **Full Detail Inspection:** Dedicated sheet viewer for long messages and code snippets, preserving line breaks, indentation, and formatting.
- **Scoped Retention & History Cleanup:** Delete items for Today, Yesterday, This Week, This Month, or Last 90 Days with confirmation prompts. Favorites are unconditionally preserved.
- **Launch at Login:** Native `SMAppService` integration to start automatically on macOS login.
- **100% Local Privacy:** Zero cloud sync, zero telemetry, zero plain-text clipboard console logging.

---

### Assets Included
- `ClipboardLibrary.dmg` — Recommended drag-and-drop installer for macOS.
- `ClipboardLibrary.zip` — Portable zip archive of the standalone `.app` bundle.

---

### Installation Instructions
1. Download `ClipboardLibrary.dmg`.
2. Double-click to mount the disk image.
3. Drag **Clipboard Library** into your **Applications** folder.
4. Open **Clipboard Library** from Applications.

> **First Launch Gatekeeper Notice:**  
> If macOS alerts that the app is from an "unidentified developer" (prior to Apple Notarization), right-click (or Control-click) `Clipboard Library.app` and choose **Open**, then confirm **Open** in the dialog.

---

### Required macOS Permissions
- **Accessibility (Optional, for Global Auto-Paste):**  
  Required only if you wish to use global keyboard shortcuts that automatically simulate `⌘V` to paste text into other applications. If permission is not granted, triggering a favorite shortcut safely copies the text to the clipboard.  
  Enable in: `System Settings → Privacy & Security → Accessibility → Clipboard Library`.

---

### Known Limitations
- **Plain-Text Primary:** Formatted rich text (RTF styling, HTML elements, embedded images, file drops) is saved as plain text in V1.
- **Local Mac Storage:** Storage is strictly local (`SwiftData` store in `~/Library/Application Support/`); multi-device cloud synchronization is deliberately excluded for maximum privacy.
