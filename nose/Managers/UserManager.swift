import Foundation
import FirebaseAuth
import FirebaseFirestore

final class UserManager {
    static let shared = UserManager()
    private let storage = UserStorage.shared
    
    private init() {}
    
    // MARK: - User Operations
    
    func createUser(email: String, password: String, name: String, completion: @escaping (Result<User, Error>) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let authResult = result else {
                completion(.failure(NSError(domain: "UserManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create user"])))
                return
            }
            
            let user = User(
                id: authResult.user.uid,
                email: email,
                name: name,
                createdAt: Date(),
                preferences: User.UserPreferences()
            )
            
            self?.storage.saveUser(user) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(user))
                }
            }
        }
    }
    
    func signIn(email: String, password: String, completion: @escaping (Result<User, Error>) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let userId = result?.user.uid else {
                completion(.failure(NSError(domain: "UserManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get user ID"])))
                return
            }
            
            self?.storage.getUser(id: userId, completion: completion)
        }
    }
    
    func signOut() throws {
        try Auth.auth().signOut()
    }
    
    func getCurrentUser(completion: @escaping (Result<User, Error>) -> Void) {
        storage.getCurrentUser(completion: completion)
    }
    
    func updateUserPreferences(preferences: User.UserPreferences, completion: @escaping (Error?) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(NSError(domain: "UserManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user logged in"]))
            return
        }
        
        storage.updateUserPreferences(userId: userId, preferences: preferences, completion: completion)
    }
    
    func deleteAccount(completion: @escaping (Error?) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion(NSError(domain: "UserManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user logged in"]))
            return
        }
        
        // First delete user data
        storage.deleteUser(userId: user.uid) { [weak self] error in
            if let error = error {
                completion(error)
                return
            }
            
            // Then delete the Firebase Auth account
            user.delete { error in
                completion(error)
            }
        }
    }
    
    // MARK: - Profile Image Operations
    
    func uploadProfileImage(_ imageData: Data, completion: @escaping (Result<URL, Error>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "UserManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])))
            return
        }
        
        storage.uploadProfileImage(imageData, userId: userId, completion: completion)
    }
    
    func downloadProfileImage(completion: @escaping (Result<Data, Error>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "UserManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])))
            return
        }
        
        storage.downloadProfileImage(userId: userId, completion: completion)
    }
    
    func deleteProfileImage(completion: @escaping (Error?) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(NSError(domain: "UserManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user logged in"]))
            return
        }
        
        storage.deleteProfileImage(userId: userId, completion: completion)
    }
} 