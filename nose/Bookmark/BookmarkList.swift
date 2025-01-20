import Foundation

struct BookmarkList: Equatable {
    let name: String
    var bookmarks: [BookmarkedPOI]

    static func == (lhs: BookmarkList, rhs: BookmarkList) -> Bool {
        return lhs.name == rhs.name
    }
}
