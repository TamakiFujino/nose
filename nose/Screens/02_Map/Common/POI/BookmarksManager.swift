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
        if let data = UserDefaults.standard.data(forKey: "bookmarkLists"),
           let lists = try? JSONDecoder().decode([BookmarkList].self, from: data) {
            bookmarkLists = lists
        }
    }
    
    func loadSharedBookmarkLists() {
        // Implement loading logic from persistent storage if needed
        if let data = UserDefaults.standard.data(forKey: "sharedBookmarkLists"),
           let lists = try? JSONDecoder().decode([BookmarkList].self, from: data) {
            sharedBookmarkLists = lists
        }
    }
    
    func saveBookmarkLists() {
        // Implement saving logic to persistent storage if needed
        if let data = try? JSONEncoder().encode(bookmarkLists) {
            UserDefaults.standard.set(data, forKey: "bookmarkLists")
        }
    }
    
    func saveSharedBookmarkLists() {
        // Implement saving logic to persistent storage if needed
        if let data = try? JSONEncoder().encode(sharedBookmarkLists) {
            UserDefaults.standard.set(data, forKey: "sharedBookmarkLists")
        }
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
    
    // New methods to save and load POIs for a user using UserDefaults
    func savePOI(for user: String, placeID: String) {
        var userPOIs = UserDefaults.standard.array(forKey: user) as? [String] ?? []
        if !userPOIs.contains(placeID) {
            userPOIs.append(placeID)
            UserDefaults.standard.set(userPOIs, forKey: user)
        }
    }
    
    func loadPOIs(for user: String) -> [String] {
        return UserDefaults.standard.array(forKey: user) as? [String] ?? []
    }
    
    func deletePOI(for user: String, placeID: String) {
        var userPOIs = UserDefaults.standard.array(forKey: user) as? [String] ?? []
        if let index = userPOIs.firstIndex(of: placeID) {
            userPOIs.remove(at: index)
            UserDefaults.standard.set(userPOIs, forKey: user)
        }
    }
}
