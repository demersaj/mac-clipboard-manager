# Mac Clipboard Manager - Product Specification

## User Story

As a Mac power user, I want a lightweight clipboard manager that lives in my menu bar, so I can retrieve any recently copied item (text, image, link, file, or table) quickly without breaking my workflow.

## Success Criteria

1. User can retrieve any of the last 100 copied items within 2 keystrokes from any app
2. User can search clipboard history and find a result in under 3 seconds
3. App uses less than 100MB RAM at idle with a full history loaded
4. Clipboard items persist across reboots
5. User can pin frequently used items and access them in under 1 second

## Functional Requirements

### Core History
1. Capture all clipboard events system-wide and store them in a local history
2. Support the following content types: plain text, rich text, images (PNG, JPEG, GIF, HEIC), URLs, file paths, and tabular data
3. Retain the last 100 items by default; user-configurable up to 500
4. Deduplicate consecutive identical copies (do not add same item twice in a row)
5. Show a preview for each item: truncated text, thumbnail for images, favicon + domain for URLs

### Retrieval
6. Global keyboard shortcut (default: `Cmd+Shift+V`) opens the clipboard panel from any app
7. Panel displays items in reverse chronological order
8. Clicking or pressing `Enter` on an item copies it to the active clipboard and dismisses the panel
9. Pressing `Cmd+Enter` pastes the item directly into the focused app without extra steps

### Search and Filtering
10. Instant search filters items as the user types, matching text content and URL domains
11. Filter by content type (text, image, URL, file, table) via keyboard shortcut or tab
12. "Pinned" category for items the user has explicitly saved; pinned items do not expire

### Organization
13. User can pin any item; pinned items appear in a persistent section at the top
14. User can manually delete individual items
15. User can clear all unpinned history with a single action (with confirmation)

### Privacy
16. User can pause capture at any time via a menu bar toggle ("Pause / Resume")
17. User can define app-based exclusions (e.g., 1Password, banking apps) - clipboard events from excluded apps are never stored
18. All data is stored locally; no network access required or permitted for core functionality

## Non-Functional Requirements

1. **Performance**: Panel must open in under 150ms after hotkey press
2. **Memory**: Idle RAM usage must not exceed 50MB with 500 items loaded
3. **Persistence**: History survives app restarts and system reboots
4. **Reliability**: Must not interfere with normal clipboard behavior in any app
5. **Compatibility**: Supports macOS 13 (Ventura) and later
6. **Accessibility**: Full keyboard navigation; VoiceOver support for text items

## Explicit Constraints

1. No cloud sync in v1 - local storage only
2. No Safari/browser extension in v1
3. Must not request Full Disk Access or any permission beyond Accessibility (required for paste) and standard pasteboard access
4. App must be sandboxable for potential Mac App Store distribution; avoid private APIs
5. No Electron - must be a native macOS app (SwiftUI preferred)

## Technical Context

- **Platform**: macOS 13+, native Swift/SwiftUI
- **Storage**: SQLite via GRDB or Core Data for history; file-backed store for image blobs
- **Clipboard polling**: `NSPasteboard.changeCount` polling at 0.5s interval OR `NSWorkspace` notifications where applicable
- **Hotkey**: `CGEventTap` or `MASShortcut` for global shortcut registration
- **UI**: Menu bar extra (`NSStatusItem`) with a floating panel (`NSPanel`); no Dock icon

## Acceptance Tests

| # | Scenario | Steps | Expected Result |
|---|----------|-------|-----------------|
| 1 | Basic copy captured | Copy text in TextEdit, open panel | Item appears at top of history |
| 2 | Image captured | Copy image in Preview, open panel | Thumbnail visible in history |
| 3 | Paste shortcut works | Open panel, select item, press `Cmd+Enter` | Item pasted into focused app |
| 4 | Search works | Open panel, type partial text | Matching items filtered in real time |
| 5 | Excluded app respected | Copy from 1Password, open panel | Item does not appear in history |
| 6 | Pinned item persists | Pin an item, clear history | Pinned item still present |
| 7 | History persists on reboot | Add items, restart Mac, open panel | Items still present |
| 8 | Pause capture | Toggle pause, copy text | Item does not appear in history |
| 9 | Memory under load | Load 500 items, idle 5 min | Activity Monitor shows <50MB RAM |
| 10 | No clipboard interference | Copy/paste normally in any app | Behavior identical to clipboard-manager-absent state |