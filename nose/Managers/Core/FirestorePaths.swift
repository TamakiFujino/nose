import FirebaseFirestore

enum FirestorePaths {
    static func users(_ db: Firestore = Firestore.firestore()) -> CollectionReference {
        return db.collection("users")
    }

    static func userDoc(_ userId: String, db: Firestore = Firestore.firestore()) -> DocumentReference {
        return users(db).document(userId)
    }

    static func collections(userId: String, db: Firestore = Firestore.firestore()) -> CollectionReference {
        return userDoc(userId, db: db).collection("collections")
    }

    static func friends(userId: String, db: Firestore = Firestore.firestore()) -> CollectionReference {
        return userDoc(userId, db: db).collection("friends")
    }

    static func blocked(userId: String, db: Firestore = Firestore.firestore()) -> CollectionReference {
        return userDoc(userId, db: db).collection("blocked")
    }
}


