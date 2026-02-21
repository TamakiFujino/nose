import Foundation

enum TestConfig {

    // MARK: - Test User Credentials

    enum UserA {
        static let email = "tamakifujino526@gmail.com"
        static let name = "Tamaki Fujino"
        static let displayName = "User A"
    }

    enum UserB {
        static let email = "lionpearl77@gmail.com"
        static let name = "Tama"
        static let displayName = "Name to be updated"
        static let updatedName = "User B"
    }

    // MARK: - Shared State (persisted across test classes via UserDefaults)

    private static let defaults = UserDefaults(suiteName: "com.nose.uitests")!

    static var userAId: String? {
        get { defaults.string(forKey: "user_a_id") }
        set { defaults.set(newValue, forKey: "user_a_id") }
    }

    static var userBId: String? {
        get { defaults.string(forKey: "user_b_id") }
        set { defaults.set(newValue, forKey: "user_b_id") }
    }
}
