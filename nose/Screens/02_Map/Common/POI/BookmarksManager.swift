import Foundation

class BookmarksManager {
    static let shared = BookmarksManager()
    
    var bookmarkLists: [BookmarkList] = []
    var sharedBookmarkLists: [BookmarkList] = []
    
    private init() {
        // Load initial data if needed
        loadBookmarkLists()
        loadSharedBookmarkLists()
    }
    
    func loadBookmarkLists() {
        // Implement loading logic from persistent storage if needed
    }
    
    func loadSharedBookmarkLists() {
        // Implement loading logic from persistent storage if needed
    }
    
    func saveBookmarkLists() {
        // Implement saving logic to persistent storage if needed
    }
    
    func saveSharedBookmarkLists() {
        // Implement saving logic to persistent storage if needed
    }
    
    func createBookmarkList(name: String) {
        let newList = BookmarkList(name: name, bookmarks: [])
        bookmarkLists.append(newList)
        saveBookmarkLists()
    }
    
    func saveBookmarkList(_ list: BookmarkList) {
        if let index = bookmarkLists.firstIndex(where: { $0.name == list.name }) {
            bookmarkLists[index] = list
        } else {
            bookmarkLists.append(list)
        }
        saveBookmarkLists()
    }
    
    func deleteBookmarkList(_ list: BookmarkList) {
        if let index = bookmarkLists.firstIndex(where: { $0.name == list.name }) {
            bookmarkLists.remove(at: index)
        }
        saveBookmarkLists()
    }
    
    func deleteSharedBookmarkList(_ list: BookmarkList) {
        if let index = sharedBookmarkLists.firstIndex(where: { $0.name == list.name }) {
            sharedBookmarkLists.remove(at: index)
        }
        saveSharedBookmarkLists()
    }
    
    func unfriendUser(_ list: BookmarkList) {
        deleteBookmarkList(list)
    }
}
