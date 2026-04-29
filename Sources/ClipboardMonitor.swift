import AppKit
import Combine

final class ClipboardMonitor: ObservableObject {
    @Published var paused: Bool = false
    @Published var excludedBundleIDs: Set<String> = []

    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?
    private weak var store: HistoryStore?

    init(store: HistoryStore) {
        self.store = store
        self.lastChangeCount = pasteboard.changeCount
        loadSettings()
        start()
    }

    deinit { timer?.invalidate() }

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func setPaused(_ p: Bool) {
        paused = p
        UserDefaults.standard.set(p, forKey: "paused")
    }

    func setExcludedBundleIDs(_ ids: Set<String>) {
        excludedBundleIDs = ids
        UserDefaults.standard.set(Array(ids), forKey: "excludedBundleIDs")
    }

    private func loadSettings() {
        paused = UserDefaults.standard.bool(forKey: "paused")
        if let arr = UserDefaults.standard.stringArray(forKey: "excludedBundleIDs") {
            excludedBundleIDs = Set(arr)
        }
    }

    private func poll() {
        guard !paused else { return }
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        let frontApp = NSWorkspace.shared.frontmostApplication
        if let bid = frontApp?.bundleIdentifier, excludedBundleIDs.contains(bid) { return }

        // Respect transient/concealed clipboard hints (used by password managers).
        let types = pasteboard.types ?? []
        let concealed = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
        let transient = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")
        if types.contains(concealed) || types.contains(transient) { return }

        guard let item = makeItem(sourceApp: frontApp?.localizedName) else { return }
        store?.add(item)
    }

    private func makeItem(sourceApp: String?) -> ClipboardItem? {
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty {
            if urls.allSatisfy({ $0.isFileURL }) {
                let paths = urls.map { $0.path }.joined(separator: "\n")
                return ClipboardItem(id: UUID(), createdAt: Date(), type: .file, text: paths,
                                     richTextRTF: nil, imageFilename: nil, sourceApp: sourceApp, pinned: false)
            }
            if let url = urls.first(where: { !$0.isFileURL }) {
                return ClipboardItem(id: UUID(), createdAt: Date(), type: .url, text: url.absoluteString,
                                     richTextRTF: nil, imageFilename: nil, sourceApp: sourceApp, pinned: false)
            }
        }

        if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let img = images.first,
           let tiff = img.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            let name = store?.saveImage(png, ext: "png") ?? ""
            return ClipboardItem(id: UUID(), createdAt: Date(), type: .image, text: nil,
                                 richTextRTF: nil, imageFilename: name, sourceApp: sourceApp, pinned: false)
        }

        if let text = pasteboard.string(forType: .string) {
            let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
            if lines.count > 1 && lines.allSatisfy({ $0.contains("\t") }) {
                return ClipboardItem(id: UUID(), createdAt: Date(), type: .table, text: text,
                                     richTextRTF: nil, imageFilename: nil, sourceApp: sourceApp, pinned: false)
            }
            if let rtfData = pasteboard.data(forType: .rtf) {
                return ClipboardItem(id: UUID(), createdAt: Date(), type: .richText, text: text,
                                     richTextRTF: rtfData, imageFilename: nil, sourceApp: sourceApp, pinned: false)
            }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if (trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://")), URL(string: trimmed) != nil, !trimmed.contains(" ") {
                return ClipboardItem(id: UUID(), createdAt: Date(), type: .url, text: trimmed,
                                     richTextRTF: nil, imageFilename: nil, sourceApp: sourceApp, pinned: false)
            }
            return ClipboardItem(id: UUID(), createdAt: Date(), type: .text, text: text,
                                 richTextRTF: nil, imageFilename: nil, sourceApp: sourceApp, pinned: false)
        }
        return nil
    }
}
