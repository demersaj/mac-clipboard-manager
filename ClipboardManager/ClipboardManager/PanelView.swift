import SwiftUI
import AppKit

extension Notification.Name {
    static let closeClipboardPanel = Notification.Name("closeClipboardPanel")
}

struct PanelView: View {
    @ObservedObject var store: HistoryStore
    @ObservedObject var monitor: ClipboardMonitor
    var onSelect: (ClipboardItem, Bool) -> Void

    @State private var search = ""
    @State private var typeFilter: ClipboardContentType? = nil
    @State private var selectionIndex: Int = 0
    @FocusState private var searchFocused: Bool

    var filtered: [ClipboardItem] {
        var items = store.items
        if let t = typeFilter { items = items.filter { $0.type == t } }
        if !search.isEmpty {
            let q = search.lowercased()
            items = items.filter { item in
                if let txt = item.text, txt.lowercased().contains(q) { return true }
                if let app = item.sourceApp, app.lowercased().contains(q) { return true }
                return false
            }
        }
        return items
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("Search clipboard…", text: $search)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .onSubmit { selectAndDismiss(paste: false) }
                if monitor.paused {
                    Text("PAUSED").font(.caption2).bold()
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.orange.opacity(0.25)).cornerRadius(4)
                }
            }
            .padding(8)

            HStack(spacing: 4) {
                FilterChip(label: "All", active: typeFilter == nil) { typeFilter = nil; selectionIndex = 0 }
                ForEach(ClipboardContentType.allCases, id: \.self) { t in
                    FilterChip(label: t.label, active: typeFilter == t) { typeFilter = t; selectionIndex = 0 }
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 6)

            Divider()

            if filtered.isEmpty {
                Spacer()
                Text(store.items.isEmpty ? "No clipboard history yet.\nCopy something to get started." : "No matches.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .font(.callout)
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, item in
                                ItemRow(item: item, store: store, isSelected: idx == selectionIndex)
                                    .id(item.id)
                                    .contentShape(Rectangle())
                                    .onTapGesture(count: 2) {
                                        selectionIndex = idx
                                        selectAndDismiss(paste: true)
                                    }
                                    .onTapGesture {
                                        selectionIndex = idx
                                    }
                                    .contextMenu {
                                        Button(item.pinned ? "Unpin" : "Pin") { store.togglePin(item.id) }
                                        Button("Copy") { selectionIndex = idx; selectAndDismiss(paste: false) }
                                        Button("Paste") { selectionIndex = idx; selectAndDismiss(paste: true) }
                                        Divider()
                                        Button("Delete", role: .destructive) { store.delete(item.id) }
                                    }
                            }
                        }
                    }
                    .onChange(of: selectionIndex) { _, new in
                        if filtered.indices.contains(new) {
                            withAnimation(.linear(duration: 0.05)) {
                                proxy.scrollTo(filtered[new].id, anchor: .center)
                            }
                        }
                    }
                }
            }

            Divider()
            HStack(spacing: 12) {
                Label("↩ copy", systemImage: "return")
                Label("⌘↩ paste", systemImage: "command")
                Label("⌘P pin", systemImage: "pin")
                Spacer()
                Text("\(filtered.count)/\(store.items.count)")
            }
            .font(.caption2)
            .foregroundColor(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .frame(width: 440, height: 500)
        .background(.regularMaterial)
        .onAppear {
            searchFocused = true
            selectionIndex = 0
        }
        .onKeyPress(.downArrow) {
            if !filtered.isEmpty { selectionIndex = min(selectionIndex + 1, filtered.count - 1) }
            return .handled
        }
        .onKeyPress(.upArrow) {
            selectionIndex = max(selectionIndex - 1, 0)
            return .handled
        }
        .onKeyPress(.return) {
            let paste = NSEvent.modifierFlags.contains(.command)
            selectAndDismiss(paste: paste)
            return .handled
        }
        .onKeyPress(.escape) {
            NotificationCenter.default.post(name: .closeClipboardPanel, object: nil)
            return .handled
        }
        .onKeyPress(.delete) {
            if filtered.indices.contains(selectionIndex) {
                let id = filtered[selectionIndex].id
                store.delete(id)
                selectionIndex = min(selectionIndex, max(0, filtered.count - 2))
            }
            return .handled
        }
        .onKeyPress(keys: ["p"]) { press in
            if press.modifiers.contains(.command), filtered.indices.contains(selectionIndex) {
                store.togglePin(filtered[selectionIndex].id)
                return .handled
            }
            return .ignored
        }
    }

    private func selectAndDismiss(paste: Bool) {
        guard filtered.indices.contains(selectionIndex) else { return }
        onSelect(filtered[selectionIndex], paste)
    }
}

struct FilterChip: View {
    let label: String
    let active: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(active ? Color.accentColor.opacity(0.25) : Color.secondary.opacity(0.08))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct ItemRow: View {
    let item: ClipboardItem
    let store: HistoryStore
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            if item.pinned {
                Image(systemName: "pin.fill").font(.caption2).foregroundColor(.orange)
            }
            Group {
                if item.type == .image,
                   let f = item.imageFilename,
                   let img = NSImage(contentsOf: store.imageURL(for: f)) {
                    Image(nsImage: img)
                        .resizable().scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipped().cornerRadius(4)
                } else {
                    Image(systemName: icon)
                        .frame(width: 36, height: 36)
                        .foregroundColor(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.preview.replacingOccurrences(of: "\n", with: " "))
                    .lineLimit(2)
                    .font(.system(size: 12))
                HStack(spacing: 6) {
                    Text(item.type.label).font(.caption2).foregroundColor(.secondary)
                    if let app = item.sourceApp {
                        Text("· \(app)").font(.caption2).foregroundColor(.secondary)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor.opacity(0.20) : Color.clear)
        .accessibilityLabel(Text(item.preview))
    }

    var icon: String {
        switch item.type {
        case .text: return "doc.plaintext"
        case .richText: return "doc.richtext"
        case .image: return "photo"
        case .url: return "link"
        case .file: return "doc"
        case .table: return "tablecells"
        }
    }
}
