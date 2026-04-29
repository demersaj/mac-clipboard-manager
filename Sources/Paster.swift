import AppKit

enum Paster {
    static func copyToPasteboard(_ item: ClipboardItem, store: HistoryStore) {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch item.type {
        case .image:
            if let f = item.imageFilename,
               let data = try? Data(contentsOf: store.imageURL(for: f)),
               let img = NSImage(data: data) {
                pb.writeObjects([img])
            }
        case .url:
            if let s = item.text, let url = URL(string: s) {
                pb.writeObjects([url as NSURL])
                pb.setString(s, forType: .string)
            }
        case .richText:
            if let rtf = item.richTextRTF { pb.setData(rtf, forType: .rtf) }
            if let s = item.text { pb.setString(s, forType: .string) }
        case .file:
            if let s = item.text {
                let urls = s.split(separator: "\n").compactMap { URL(fileURLWithPath: String($0)) as NSURL? }
                if !urls.isEmpty { pb.writeObjects(urls) }
                pb.setString(s, forType: .string)
            }
        default:
            if let s = item.text { pb.setString(s, forType: .string) }
        }
    }

    /// Posts a synthetic Cmd+V to the focused app. Requires Accessibility permission.
    static func simulatePaste() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let v: CGKeyCode = 0x09 // kVK_ANSI_V
        let down = CGEvent(keyboardEventSource: src, virtualKey: v, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: v, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    static func ensureAccessibilityPermission() -> Bool {
        let key = "AXTrustedCheckOptionPrompt" as CFString
        let opts = [key: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }
}
