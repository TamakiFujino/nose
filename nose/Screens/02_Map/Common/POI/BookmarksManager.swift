import Foundation

class BookmarksManager {
    static let shared = BookmarksManager()
    
    private(set) var bookmarkLists: [BookmarkList] = []
    private(set) var sharedBookmarkLists: [BookmarkList] = []
    private(set) var completedLists: [BookmarkList] = []
    
    private init() {
        loadBookmarkLists()
        loadSharedBookmarkLists()
        loadCompletedLists()
    }
    
    // MARK: - Bookmark List Management
    
    func createBookmarkList(name: String) {
        let newList = BookmarkList(name: name, bookmarks: [])
        bookmarkLists.append(newList)
        saveBookmarkLists()
    }
    
    func saveBookmarkList(_ list: BookmarkList) {
        if let index = bookmarkLists.firstIndex(where: { $0.id == list.id }) {
            bookmarkLists[index] = list
        } else {
            bookmarkLists.append(list)
        }
        saveBookmarkLists()
    }
    
    func deleteBookmarkList(_ list: BookmarkList) {
        bookmarkLists.removeAll { $0.id == list.id }
        saveBookmarkLists()
    }
    
    func deleteSharedBookmarkList(_ list: BookmarkList) {
        sharedBookmarkLists.removeAll { $0.id == list.id }
        saveSharedBookmarkLists()
    }
    
    func completeBookmarkList(_ list: BookmarkList) {
        if let index = bookmarkLists.firstIndex(where: { $0.id == list.id }) {
            let completedList = bookmarkLists.remove(at: index)
            completedLists.append(completedList)
            saveBookmarkLists()
            saveCompletedLists()
        }
    }
    
    // MARK: - Data Persistence
    
    private func saveBookmarkLists() {
        if let data = try? JSONEncoder().encode(bookmarkLists) {
            UserDefaults.standard.set(data, forKey: "bookmarkLists")
        }
    }
    
    private func saveSharedBookmarkLists() {
        if let data = try? JSONEncoder().encode(sharedBookmarkLists) {
            UserDefaults.standard.set(data, forKey: "sharedBookmarkLists")
        }
    }
    
    private func saveCompletedLists() {
        if let data = try? JSONEncoder().encode(completedLists) {
            UserDefaults.standard.set(data, forKey: "completedLists")
        }
    }
    
    private func loadBookmarkLists() {
        if let data = UserDefaults.standard.data(forKey: "bookmarkLists"),
           let lists = try? JSONDecoder().decode([BookmarkList].self, from: data) {
            bookmarkLists = lists
        }
    }
    
    private func loadSharedBookmarkLists() {
        if let data = UserDefaults.standard.data(forKey: "sharedBookmarkLists"),
           let lists = try? JSONDecoder().decode([BookmarkList].self, from: data) {
            sharedBookmarkLists = lists
        }
    }
    
    private func loadCompletedLists() {
        if let data = UserDefaults.standard.data(forKey: "completedLists"),
           let lists = try? JSONDecoder().decode([BookmarkList].self, from: data) {
            completedLists = lists
        }
    }
    
    // MARK: - POI Management
    
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
