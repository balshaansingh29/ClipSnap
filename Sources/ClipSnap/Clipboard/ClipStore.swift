import Foundation

/// Persistent clipboard history. Metadata lives in history.json; image and RTF
/// payloads are kept as separate files so the JSON stays small and fast to load.
@MainActor
final class ClipStore: ObservableObject {
    @Published private(set) var items: [ClipItem] = []

    private let folder: URL
    private let blobs: URL
    private let file: URL
    private let settings = AppSettings.shared

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ClipSnap", isDirectory: true)
        folder = base
        blobs = base.appendingPathComponent("Blobs", isDirectory: true)
        file = base.appendingPathComponent("history.json")
        try? FileManager.default.createDirectory(at: blobs, withIntermediateDirectories: true)
        load()
    }

    // MARK: Queries

    /// Pinned first, then newest first; filtered by a case-insensitive substring.
    func filtered(_ query: String) -> [ClipItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = q.isEmpty ? items : items.filter {
            ($0.text ?? "").localizedCaseInsensitiveContains(q)
                || ($0.sourceName ?? "").localizedCaseInsensitiveContains(q)
        }
        return base.filter(\.pinned) + base.filter { !$0.pinned }
    }

    func blobURL(_ name: String) -> URL { blobs.appendingPathComponent(name) }

    // MARK: Mutations

    /// Adds a new clip, or bumps an existing identical one to the top.
    func add(_ new: ClipItem, rtf: Data? = nil, png: Data? = nil) {
        if let i = items.firstIndex(where: { $0.key == new.key }) {
            var existing = items.remove(at: i)
            existing.date = Date()
            existing.sourceBundleID = new.sourceBundleID ?? existing.sourceBundleID
            existing.sourceName = new.sourceName ?? existing.sourceName
            items.insert(existing, at: 0)
            save()
            return
        }
        var item = new
        if let rtf {
            let name = "\(item.id.uuidString).rtf"
            try? rtf.write(to: blobURL(name))
            item.rtfFile = name
        }
        if let png {
            let name = "\(item.id.uuidString).png"
            try? png.write(to: blobURL(name))
            item.imageFile = name
        }
        items.insert(item, at: 0)
        prune()
        save()
    }

    func togglePin(_ item: ClipItem) {
        guard let i = items.firstIndex(of: item) else { return }
        items[i].pinned.toggle()
        save()
    }

    func delete(_ item: ClipItem) {
        guard let i = items.firstIndex(of: item) else { return }
        removeBlobs(of: items[i])
        items.remove(at: i)
        save()
    }

    func clearUnpinned() {
        for item in items where !item.pinned { removeBlobs(of: item) }
        items.removeAll { !$0.pinned }
        save()
    }

    // MARK: Internals

    private func prune() {
        let limit = max(10, settings.maxHistory)
        var unpinned = 0
        var keep: [ClipItem] = []
        for item in items {
            if item.pinned { keep.append(item); continue }
            unpinned += 1
            if unpinned <= limit { keep.append(item) } else { removeBlobs(of: item) }
        }
        items = keep
    }

    private func removeBlobs(of item: ClipItem) {
        for name in [item.rtfFile, item.imageFile].compactMap({ $0 }) {
            try? FileManager.default.removeItem(at: blobURL(name))
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: file),
              let decoded = try? JSONDecoder().decode([ClipItem].self, from: data) else { return }
        items = decoded
    }

    private func save() {
        let snapshot = items
        let url = file
        // Encode on the main actor (small), write off-thread.
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        DispatchQueue.global(qos: .utility).async {
            try? data.write(to: url, options: .atomic)
        }
    }
}
