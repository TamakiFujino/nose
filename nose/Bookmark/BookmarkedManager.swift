import Foundation

class BookmarksManager {
    static let shared = BookmarksManager()
    private(set) var bookmarkLists = [BookmarkList]()
    
    private init() {}
    
    // Create a new bookmark list
    func createBookmarkList(name: String) {
        bookmarkLists.append(BookmarkList(name: name, bookmarks: []))
    }
    
    // Add a bookmark to a specific list
    func addBookmark(_ poi: BookmarkedPOI, to listName: String) {
        if let index = bookmarkLists.firstIndex(where: { $0.name == listName }) {
            bookmarkLists[index].bookmarks.append(poi)
        }
    }
    
    // Remove a bookmark from a specific list
    func removeBookmark(_ poi: BookmarkedPOI, from listName: String) {
        if let index = bookmarkLists.firstIndex(where: { $0.name == listName }) {
            bookmarkLists[index].bookmarks.removeAll { $0.placeID == poi.placeID }
        }
    }
}
