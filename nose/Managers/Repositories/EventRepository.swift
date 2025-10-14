import Foundation

protocol EventRepository {
    func createEvent(_ event: Event, avatarData: CollectionAvatar.AvatarData?, completion: @escaping (Result<String, Error>) -> Void)
    func updateEvent(_ event: Event, avatarData: CollectionAvatar.AvatarData?, completion: @escaping (Result<Void, Error>) -> Void)
}

final class FirebaseEventRepository: EventRepository {
    func createEvent(_ event: Event, avatarData: CollectionAvatar.AvatarData?, completion: @escaping (Result<String, Error>) -> Void) {
        EventManager.shared.createEvent(event, avatarData: avatarData, completion: completion)
    }
    
    func updateEvent(_ event: Event, avatarData: CollectionAvatar.AvatarData?, completion: @escaping (Result<Void, Error>) -> Void) {
        EventManager.shared.updateEvent(event, avatarData: avatarData, completion: completion)
    }
}


