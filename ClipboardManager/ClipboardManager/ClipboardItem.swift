import Foundation

enum ClipboardContentType: String, Codable, CaseIterable {
    case text, richText, image, url, file, table

    var label: String {
        switch self {
        case .text: return "Text"
        case .richText: return "Rich"
        case .image: return "Image"
        case .url: return "URL"
        case .file: return "File"
        case .table: return "Table"
        }
    }
}

struct ClipboardItem: Identifiable, Codable, Equatable {
    let id: UUID
    let createdAt: Date
    let type: ClipboardContentType
    var text: String?
    var richTextRTF: Data?
    var imageFilename: String?
    var sourceApp: String?
    var pinned: Bool

    var preview: String {
        switch type {
        case .image: return "[Image]"
        default: return text ?? ""
        }
    }
}
