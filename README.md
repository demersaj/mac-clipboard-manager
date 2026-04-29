# Clipboard Manager (macOS)

A native, menu-bar-only clipboard history app built to the spec in
`Mac Clipboard History Specification.md`. Pure SwiftUI + AppKit, no
third-party dependencies, local-only storage.

## Features

- Lives in the menu bar (no Dock icon)
- Global hotkey: **⌘⇧V**
- Captures text, rich text, images, URLs, file paths, and tabular (TSV) data
- Pin items, type filters, instant search
- Per-app exclusions (bundle ID list) and Pause/Resume
- `↩` to copy, `⌘↩` to paste directly into the focused app
- `⌘P` to pin, `⌫` to delete, `↑/↓` to navigate, `Esc` to dismiss
- Persists to `~/Library/Application Support/ClipboardManager/`
- Launch at Login via `SMAppService` (one click in the menu)
- Honors `org.nspasteboard.ConcealedType` / `TransientType` (password managers)

## One-time Xcode setup (≈3 minutes)

You'll create an empty Xcode app project once, drop these source files into it, and build. After that, daily use is just `⌘⇧V`.

1. **Open Xcode → File → New → Project → macOS → App**.
   - Product Name: `ClipboardManager`
   - Team: your personal team (or "None")
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Save to: anywhere (e.g. this folder).

2. In the new project, **delete** the auto-generated files:
   - `ClipboardManagerApp.swift`
   - `ContentView.swift`
   - `Assets.xcassets` is fine to keep (optional)

3. **Drag every `.swift` file from `Sources/` into the project** in Xcode (check "Copy items if needed" and add to the `ClipboardManager` target).

4. **Replace the auto-generated `Info.plist`** content with `Sources/Info.plist`, OR in the target's **Info** tab add a row:
   - Key: `Application is agent (UIElement)` → Value: `YES`

5. **Target → General**:
   - Minimum Deployments: **macOS 13.0**

6. **Target → Signing & Capabilities**:
   - Signing: **Sign to Run Locally** (or your personal team)
   - **Disable** App Sandbox (it interferes with global pasteboard / Cmd+V injection). If you want sandboxing, you'll need to add the `com.apple.security.temporary-exception.apple-events` entitlement and accept that synthetic-paste won't work.

7. **Product → Archive → Distribute App → Copy App** → drag `ClipboardManager.app` to `/Applications`.

8. First launch: right-click → **Open** (Gatekeeper). Then in the menu bar, choose **Launch at Login**. Press `⌘⇧V` once and grant **Accessibility** permission when prompted (only required for `⌘↩` direct-paste; plain copy works without it).

That's it. From then on it just runs.

## File layout

```
Sources/
├── ClipboardManagerApp.swift   @main entry, installs AppDelegate
├── AppDelegate.swift           NSStatusItem, NSPanel, menu, hotkey wiring
├── ClipboardItem.swift         Model + content type enum
├── HistoryStore.swift          ObservableObject, JSON persistence, pin/trim
├── ClipboardMonitor.swift      0.5s changeCount poll, type detection
├── HotKey.swift                Carbon RegisterEventHotKey wrapper
├── Paster.swift                Pasteboard write + synthetic Cmd+V
├── PanelView.swift             SwiftUI search panel
└── Info.plist                  LSUIElement=YES, deployment 13.0
```

## Storage

- `~/Library/Application Support/ClipboardManager/history.json` — metadata
- `~/Library/Application Support/ClipboardManager/images/*.png` — image blobs
- `UserDefaults` — paused state, excluded bundle IDs, max history size

To reset: quit the app, `rm -rf ~/Library/Application\ Support/ClipboardManager`.

## Known limitations vs. spec

- Persistence uses JSON, not SQLite/GRDB. Fine for the 100–500 item range; swap in GRDB if you push beyond that.
- VoiceOver works on text rows but image rows only get a generic label.
- "Tabular data" detection is heuristic (multi-line TSV); spreadsheet-native types aren't introspected.
- The hotkey is fixed at ⌘⇧V (no in-app rebinding UI).
