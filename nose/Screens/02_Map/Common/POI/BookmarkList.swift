import Foundation

struct BookmarkList: Equatable {
    let id: String
    let name: String
    var bookmarks: [BookmarkedPOI]
    var sharedWithFriends: [String]

    init(name: String, bookmarks: [BookmarkedPOI] = [], sharedWithFriends: [String] = []) {
        self.id = UUID().uuidString
        self.name = name
        self.bookmarks = bookmarks
        self.sharedWithFriends = sharedWithFriends
    }

    static func == (lhs: BookmarkList, rhs: BookmarkList) -> Bool {
        return lhs.id == rhs.id
    }
}
