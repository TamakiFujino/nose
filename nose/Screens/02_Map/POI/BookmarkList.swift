import Foundation

struct BookmarkList: Equatable {
    let id: String
    let name: String
    var bookmarks: [BookmarkedPOI]

    init(name: String, bookmarks: [BookmarkedPOI] = []) {
        self.id = UUID().uuidString
        self.name = name
        self.bookmarks = bookmarks
    }

    static func == (lhs: BookmarkList, rhs: BookmarkList) -> Bool {
        return lhs.id == rhs.id
    }
}
