import AppKit
import SwiftUI
import Carbon.HIToolbox
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var panel: NSPanel?
    let store = HistoryStore()
    lazy var monitor = ClipboardMonitor(store: store)
    let hotKey = HotKey()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // belt-and-suspenders for menu bar app
        _ = monitor // start polling
        setupStatusItem()
        registerHotKey()
        NotificationCenter.default.addObserver(self, selector: #selector(closePanel),
                                               name: .closeClipboardPanel, object: nil)
    }

    // MARK: - Status item

    func setupStatusItem() {
        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        }
        if let btn = statusItem.button {
            btn.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipboard")
        }
        let menu = NSMenu()
        menu.addItem(withTitle: "Open Clipboard  ⌘⇧V", action: #selector(togglePanel), keyEquivalent: "")

        menu.addItem(.separator())

        let pauseTitle = monitor.paused ? "Resume Capture" : "Pause Capture"
        menu.addItem(withTitle: pauseTitle, action: #selector(togglePause), keyEquivalent: "")
        menu.addItem(withTitle: "Clear Unpinned History…", action: #selector(clearUnpinned), keyEquivalent: "")

        menu.addItem(.separator())

        let sizeMenu = NSMenu(title: "History Size")
        for n in [50, 100, 200, 500] {
            let mi = NSMenuItem(title: "\(n) items", action: #selector(setHistorySize(_:)), keyEquivalent: "")
            mi.tag = n
            mi.state = (store.maxItems == n) ? .on : .off
            sizeMenu.addItem(mi)
        }
        let sizeItem = NSMenuItem(title: "History Size", action: nil, keyEquivalent: "")
        sizeItem.submenu = sizeMenu
        menu.addItem(sizeItem)

        menu.addItem(withTitle: "Excluded Apps…", action: #selector(editExclusions), keyEquivalent: "")

        let launchAtLogin = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLogin.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        menu.addItem(launchAtLogin)

        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        for item in menu.items where item.action != nil && item.target == nil {
            item.target = self
        }
        statusItem.menu = menu
    }

    // MARK: - Hotkey

    func registerHotKey() {
        hotKey.register(keyCode: UInt32(kVK_ANSI_V),
                        modifiers: UInt32(cmdKey | shiftKey)) { [weak self] in
            self?.togglePanel()
        }
    }

    // MARK: - Panel

    @objc func togglePanel() {
        if let p = panel, p.isVisible {
            closePanel()
        } else {
            showPanel()
        }
    }

    func showPanel() {
        let view = PanelView(store: store, monitor: monitor) { [weak self] item, paste in
            guard let self = self else { return }
            Paster.copyToPasteboard(item, store: self.store)
            self.closePanel()
            if paste {
                if Paster.ensureAccessibilityPermission() {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        Paster.simulatePaste()
                    }
                }
            }
        }
        let host = NSHostingController(rootView: view)
        let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 440, height: 500),
                        styleMask: [.titled, .nonactivatingPanel, .fullSizeContentView, .resizable],
                        backing: .buffered, defer: false)
        p.titleVisibility = .hidden
        p.titlebarAppearsTransparent = true
        p.isFloatingPanel = true
        p.level = .floating
        p.hidesOnDeactivate = true
        p.isMovableByWindowBackground = true
        p.standardWindowButton(.closeButton)?.isHidden = true
        p.standardWindowButton(.miniaturizeButton)?.isHidden = true
        p.standardWindowButton(.zoomButton)?.isHidden = true
        p.contentViewController = host

        if let screen = NSScreen.main {
            let mouse = NSEvent.mouseLocation
            let w: CGFloat = 440, h: CGFloat = 500
            let vf = screen.visibleFrame
            let x = min(max(mouse.x - w / 2, vf.minX + 8), vf.maxX - w - 8)
            let y = min(max(mouse.y - h - 8, vf.minY + 8), vf.maxY - h - 8)
            p.setFrame(NSRect(x: x, y: y, width: w, height: h), display: true)
        } else {
            p.center()
        }

        p.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.panel = p
    }

    @objc func closePanel() {
        panel?.orderOut(nil)
        panel = nil
    }

    // MARK: - Menu actions

    @objc func togglePause() {
        monitor.setPaused(!monitor.paused)
        setupStatusItem()
    }

    @objc func clearUnpinned() {
        let alert = NSAlert()
        alert.messageText = "Clear unpinned history?"
        alert.informativeText = "Pinned items will be kept. This cannot be undone."
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        if alert.runModal() == .alertFirstButtonReturn {
            store.clearUnpinned()
        }
    }

    @objc func setHistorySize(_ sender: NSMenuItem) {
        store.setMaxItems(sender.tag)
        setupStatusItem()
    }

    @objc func editExclusions() {
        let alert = NSAlert()
        alert.messageText = "Excluded App Bundle IDs"
        alert.informativeText = "One bundle identifier per line. Example: com.agilebits.onepassword7"

        let text = NSTextView(frame: NSRect(x: 0, y: 0, width: 360, height: 140))
        text.string = monitor.excludedBundleIDs.sorted().joined(separator: "\n")
        text.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        text.isEditable = true
        text.isAutomaticQuoteSubstitutionEnabled = false

        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 360, height: 140))
        scroll.documentView = text
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder

        alert.accessoryView = scroll
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            let ids = Set(text.string
                .split(separator: "\n")
                .map { String($0).trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty })
            monitor.setExcludedBundleIDs(ids)
        }
    }

    @objc func toggleLaunchAtLogin() {
        let svc = SMAppService.mainApp
        do {
            if svc.status == .enabled {
                try svc.unregister()
            } else {
                try svc.register()
            }
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
        setupStatusItem()
    }
}
