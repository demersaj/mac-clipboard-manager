import Foundation
import AppKit
import Combine

final class HistoryStore: ObservableObject {
    @Published private(set) var items: [ClipboardItem] = []
    @Published var maxItems: Int

    private let baseURL: URL
    private let dbURL: URL
    private let imagesURL: URL

    init() {
        let fm = FileManager.default
        let appSupport = try! fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        self.baseURL = appSupport.appendingPathComponent("ClipboardManager", isDirectory: true)
        self.dbURL = baseURL.appendingPathComponent("history.json")
        self.imagesURL = baseURL.appendingPathComponent("images", isDirectory: true)
        try? fm.createDirectory(at: imagesURL, withIntermediateDirectories: true)

        let saved = UserDefaults.standard.integer(forKey: "maxItems")
        self.maxItems = saved == 0 ? 100 : min(max(saved, 10), 500)
        load()
    }

    func setMaxItems(_ n: Int) {
        maxItems = min(max(n, 10), 500)
        UserDefaults.standard.set(maxItems, forKey: "maxItems")
        trim()
        save()
    }

    func add(_ item: ClipboardItem) {
        if let mostRecent = items.first, mostRecent.type == item.type, mostRecent.preview == item.preview {
            return
        }
        items.insert(item, at: 0)
        sortItems()
        trim()
        save()
    }

    func togglePin(_ id: UUID) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].pinned.toggle()
        sortItems()
        save()
    }

    func delete(_ id: UUID) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        if let f = items[i].imageFilename {
            try? FileManager.default.removeItem(at: imagesURL.appendingPathComponent(f))
        }
        items.remove(at: i)
        save()
    }

    func clearUnpinned() {
        for item in items where !item.pinned {
            if let f = item.imageFilename {
                try? FileManager.default.removeItem(at: imagesURL.appendingPathComponent(f))
            }
        }
        items.removeAll { !$0.pinned }
        save()
    }

    func imageURL(for filename: String) -> URL {
        imagesURL.appendingPathComponent(filename)
    }

    func saveImage(_ data: Data, ext: String) -> String {
        let name = "\(UUID().uuidString).\(ext)"
        let url = imagesURL.appendingPathComponent(name)
        try? data.write(to: url)
        return name
    }

    private func sortItems() {
        items.sort { a, b in
            if a.pinned != b.pinned { return a.pinned && !b.pinned }
            return a.createdAt > b.createdAt
        }
    }

    private func trim() {
        let pinned = items.filter { $0.pinned }
        var unpinned = items.filter { !$0.pinned }
        if unpinned.count > maxItems {
            for item in unpinned[maxItems...] {
                if let f = item.imageFilename {
                    try? FileManager.default.removeItem(at: imagesURL.appendingPathComponent(f))
                }
            }
            unpinned = Array(unpinned.prefix(maxItems))
        }
        items = pinned + unpinned
    }

    private func load() {
        guard let data = try? Data(contentsOf: dbURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode([ClipboardItem].self, from: data) {
            items = decoded
            sortItems()
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(items) {
            try? data.write(to: dbURL, options: .atomic)
        }
    }
}
