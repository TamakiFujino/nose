import Foundation

struct AvatarOutfit: Codable {
    var bottoms: String
    var tops: String
    var hairBase: String
    var hairFront: String
    var hairBack: String
    var jackets: String
    var skin: String
    var eye: String
    var eyebrow: String
    var nose: String
    var mouth: String
    var socks: String
    var shoes: String
    var head: String
    var neck: String
    var eyewear: String
}

struct BookmarkList: Codable, Equatable {
    let id: String
    let name: String
    var bookmarks: [BookmarkedPOI]
    var sharedWithFriends: [String]
    var associatedOutfit: AvatarOutfit? // New property to link an outfit

    init(name: String, bookmarks: [BookmarkedPOI] = [], sharedWithFriends: [String] = [], associatedOutfit: AvatarOutfit? = nil) {
        self.id = UUID().uuidString
        self.name = name
        self.bookmarks = bookmarks
        self.sharedWithFriends = sharedWithFriends
        self.associatedOutfit = associatedOutfit
    }

    static func == (lhs: BookmarkList, rhs: BookmarkList) -> Bool {
        return lhs.id == rhs.id
    }
}
