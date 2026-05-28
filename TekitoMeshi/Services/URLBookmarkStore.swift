import Foundation

struct URLBookmark: Codable, Identifiable {
    var id: UUID = UUID()
    var label: String   // 表示名（空なら hostから自動生成）
    var url: String

    var displayLabel: String {
        if !label.isEmpty { return label }
        return URL(string: url)?.host ?? url
    }
}

final class URLBookmarkStore: ObservableObject {
    static let shared = URLBookmarkStore()
    private let key = "url_bookmarks"

    @Published private(set) var bookmarks: [URLBookmark] = []

    private init() { load() }

    func add(url: String, label: String = "") {
        guard !bookmarks.contains(where: { $0.url == url }) else { return }
        bookmarks.insert(URLBookmark(label: label, url: url), at: 0)
        save()
    }

    func delete(_ bookmark: URLBookmark) {
        bookmarks.removeAll { $0.id == bookmark.id }
        save()
    }

    func update(_ bookmark: URLBookmark) {
        guard let index = bookmarks.firstIndex(where: { $0.id == bookmark.id }) else { return }
        bookmarks[index] = bookmark
        save()
    }

    func contains(url: String) -> Bool {
        bookmarks.contains { $0.url == url }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let items = try? JSONDecoder().decode([URLBookmark].self, from: data)
        else { return }
        bookmarks = items
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(bookmarks) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
