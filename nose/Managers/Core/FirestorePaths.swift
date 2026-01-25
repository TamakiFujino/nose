import FirebaseFirestore

enum FirestorePaths {
    // MARK: - Users
    static func users(_ db: Firestore = Firestore.firestore()) -> CollectionReference {
        return db.collection("users")
    }

    static func userDoc(_ userId: String, db: Firestore = Firestore.firestore()) -> DocumentReference {
        return users(db).document(userId)
    }

    // MARK: - Collections
    static func collections(userId: String, db: Firestore = Firestore.firestore()) -> CollectionReference {
        return userDoc(userId, db: db).collection("collections")
    }
    
    static func collectionDoc(userId: String, collectionId: String, db: Firestore = Firestore.firestore()) -> DocumentReference {
        return collections(userId: userId, db: db).document(collectionId)
    }
    
    // MARK: - Events
    static func events(userId: String, db: Firestore = Firestore.firestore()) -> CollectionReference {
        return userDoc(userId, db: db).collection("events")
    }
    
    static func eventDoc(userId: String, eventId: String, db: Firestore = Firestore.firestore()) -> DocumentReference {
        return events(userId: userId, db: db).document(eventId)
    }

    // MARK: - Social
    static func friends(userId: String, db: Firestore = Firestore.firestore()) -> CollectionReference {
        return userDoc(userId, db: db).collection("friends")
    }

    static func blocked(userId: String, db: Firestore = Firestore.firestore()) -> CollectionReference {
        return userDoc(userId, db: db).collection("blocked")
    }
    
    // MARK: - Collection Members
    static func members(ownerId: String, collectionId: String, db: Firestore = Firestore.firestore()) -> CollectionReference {
        return collectionDoc(userId: ownerId, collectionId: collectionId, db: db).collection("members")
    }
}


