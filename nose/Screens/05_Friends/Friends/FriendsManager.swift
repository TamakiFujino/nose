import Foundation

class FriendsManager {
    static let shared = FriendsManager()

    var friendsList: [Friend] = []

    private init() {
        // Load initial data if needed
        loadFriendsList()
    }

    func loadFriendsList() {
        // Implement loading logic from persistent storage if needed
        // Mock data for demonstration
        friendsList = [
            Friend(id: "1", name: "Alice"),
            Friend(id: "2", name: "Bob"),
            Friend(id: "3", name: "Charlie")
        ]
    }

    func saveFriendsList() {
        // Implement saving logic to persistent storage if needed
    }

    func addFriend(_ friend: Friend) {
        friendsList.append(friend)
        saveFriendsList()
    }

    func removeFriend(_ friend: Friend) {
        if let index = friendsList.firstIndex(where: { $0.id == friend.id }) {
            friendsList.remove(at: index)
        }
        saveFriendsList()
    }
}
