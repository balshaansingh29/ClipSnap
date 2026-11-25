import Foundation

enum ClipKind: String, Codable {
    case text
    case image
}

struct ClipItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var kind: ClipKind
    var text: String?
    var rtfFile: String?        // file name inside the Blobs folder
    var imageFile: String?      // file name inside the Blobs folder
    var imageDimensions: String?
    var sourceBundleID: String?
    var sourceName: String?
    var date: Date
    var pinned = false
    var key: String             // dedupe key (text itself, or image digest)

    /// Single-line preview for list rows.
    var preview: String {
        switch kind {
        case .text:
            let t = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let collapsed = t.replacingOccurrences(of: "\n", with: " ⏎ ")
            return String(collapsed.prefix(200))
        case .image:
            return "Image \(imageDimensions ?? "")"
        }
    }
}
