// This class manages the list of bookmarked POIs
class BookmarksManager {
    static let shared = BookmarksManager()
    private(set) var bookmarks = [BookmarkedPOI]()
    
    private init() {}
    
    // Add a new bookmark
    func addBookmark(_ poi: BookmarkedPOI) {
        bookmarks.append(poi)
    }
    
    // Remove a bookmark
    func removeBookmark(withPlaceID placeID: String) {
        bookmarks.removeAll { $0.placeID == placeID }
    }
    
    // Check if a POI is bookmarked
    func isBookmarked(_ placeID: String) -> Bool {
        return bookmarks.contains { $0.placeID == placeID }
    }
}
