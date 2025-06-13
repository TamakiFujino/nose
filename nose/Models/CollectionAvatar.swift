import Foundation
import Firebase
import FirebaseFirestore

struct CollectionAvatar: Codable {
    // MARK: - Constants
    enum Version: Int, Codable {
        case v1 = 1
        case v2 = 2 // Add new versions here when making breaking changes
        
        static var current: Version { .v1 }
    }
    
    // MARK: - Properties
    let collectionId: String
    let avatarData: AvatarData
    let createdAt: Date
    let isOwner: Bool
    let version: Version
    
    // New fields with default values
    var lastModifiedAt: Date
    var isPublic: Bool
    var metadata: [String: String]
    var tags: [String]
    var status: Status
    
    enum Status: String, Codable {
        case active
        case archived
        case deleted
    }
    
    // MARK: - Nested Types
    struct AvatarData: Codable {
        // MARK: - Properties
        var selections: [String: [String: String]]
        
        // New fields with default values
        var customizations: [String: CustomizationValue]
        var lastCustomizedAt: Date?
        var customizationVersion: Int
        
        // MARK: - Nested Types
        enum CustomizationValue: Codable {
            case string(String)
            case number(Double)
            case boolean(Bool)
            case null
            
            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if container.decodeNil() {
                    self = .null
                } else if let string = try? container.decode(String.self) {
                    self = .string(string)
                } else if let number = try? container.decode(Double.self) {
                    self = .number(number)
                } else if let boolean = try? container.decode(Bool.self) {
                    self = .boolean(boolean)
                } else {
                    throw DecodingError.dataCorruptedError(
                        in: container,
                        debugDescription: "Invalid value type"
                    )
                }
            }
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                switch self {
                case .string(let value):
                    try container.encode(value)
                case .number(let value):
                    try container.encode(value)
                case .boolean(let value):
                    try container.encode(value)
                case .null:
                    try container.encodeNil()
                }
            }
            
            var stringValue: String? {
                switch self {
                case .string(let value): return value
                case .number(let value): return String(value)
                case .boolean(let value): return String(value)
                case .null: return nil
                }
            }
            
            var numberValue: Double? {
                switch self {
                case .string(let value): return Double(value)
                case .number(let value): return value
                case .boolean(let value): return value ? 1.0 : 0.0
                case .null: return nil
                }
            }
            
            var booleanValue: Bool? {
                switch self {
                case .string(let value): return Bool(value)
                case .number(let value): return value != 0
                case .boolean(let value): return value
                case .null: return nil
                }
            }
        }
        
        // MARK: - Computed Properties
        // Get color values
        var skinColor: String { AvatarCategory.getColor(from: selections, category: AvatarCategory.skin) }
        
        // Get model values for each category
        var models: [String: String] {
            var result: [String: String] = [:]
            for category in AvatarCategory.modelCategories {
                let model = AvatarCategory.getModel(from: selections, category: category)
                if !model.isEmpty {
                    result[category] = model
                }
            }
            return result
        }
        
        // MARK: - Firestore Serialization
        func toFirestoreDict() -> [String: Any] {
            var dict: [String: Any] = ["selections": selections]
            
            // Add new fields to Firestore data
            if !customizations.isEmpty {
                var firestoreCustomizations: [String: Any] = [:]
                for (key, value) in customizations {
                    switch value {
                    case .string(let str): firestoreCustomizations[key] = str
                    case .number(let num): firestoreCustomizations[key] = num
                    case .boolean(let bool): firestoreCustomizations[key] = bool
                    case .null: firestoreCustomizations[key] = NSNull()
                    }
                }
                dict["customizations"] = firestoreCustomizations
            }
            if let lastCustomizedAt = lastCustomizedAt {
                dict["lastCustomizedAt"] = Timestamp(date: lastCustomizedAt)
            }
            dict["customizationVersion"] = customizationVersion
            
            return dict
        }
        
        static func fromFirestoreDict(_ dict: [String: Any], version: Version) -> CollectionAvatar.AvatarData? {
            var selections: [String: [String: String]] = [:]
            var invalidEntries: [String] = []
            
            // Handle new fields with defaults
            var customizations: [String: CustomizationValue] = [:]
            var lastCustomizedAt: Date? = nil
            var customizationVersion: Int = 1
            
            switch version {
            case .v1:
                // Original format
                for (category, value) in dict {
                    if let valueDict = value as? [String: String] {
                        // Validate the structure of the value dictionary
                        if valueDict["model"] != nil || valueDict["color"] != nil {
                            selections[category] = valueDict
                        } else {
                            print("⚠️ Skipping invalid value structure for category: \(category)")
                            invalidEntries.append(category)
                        }
                    } else if let valueDict = value as? [String: Any] {
                        // Try to convert [String: Any] to [String: String]
                        var convertedDict: [String: String] = [:]
                        var hasValidEntries = false
                        
                        for (key, val) in valueDict {
                            if let stringVal = val as? String {
                                convertedDict[key] = stringVal
                                hasValidEntries = true
                            } else if let intVal = val as? Int {
                                convertedDict[key] = String(intVal)
                                hasValidEntries = true
                            } else if let boolVal = val as? Bool {
                                convertedDict[key] = String(boolVal)
                                hasValidEntries = true
                            }
                        }
                        
                        if hasValidEntries {
                            selections[category] = convertedDict
                        } else {
                            print("⚠️ Skipping category with no valid string values: \(category)")
                            invalidEntries.append(category)
                        }
                    } else {
                        print("⚠️ Skipping invalid value type for category: \(category)")
                        invalidEntries.append(category)
                    }
                }
                
            case .v2:
                // Handle new version with new fields
                if let selectionsDict = dict["selections"] as? [String: [String: String]] {
                    selections = selectionsDict
                }
                
                // Handle new fields
                if let customizationsDict = dict["customizations"] as? [String: Any] {
                    for (key, value) in customizationsDict {
                        if let stringValue = value as? String {
                            customizations[key] = .string(stringValue)
                        } else if let numberValue = value as? Double {
                            customizations[key] = .number(numberValue)
                        } else if let intValue = value as? Int {
                            customizations[key] = .number(Double(intValue))
                        } else if let boolValue = value as? Bool {
                            customizations[key] = .boolean(boolValue)
                        } else if value is NSNull {
                            customizations[key] = .null
                        }
                    }
                }
                
                if let timestamp = dict["lastCustomizedAt"] as? Timestamp {
                    lastCustomizedAt = timestamp.dateValue()
                } else if let date = dict["lastCustomizedAt"] as? Date {
                    lastCustomizedAt = date
                }
                
                if let version = dict["customizationVersion"] as? Int {
                    customizationVersion = version
                }
            }
            
            if !invalidEntries.isEmpty {
                print("⚠️ Skipped \(invalidEntries.count) invalid entries: \(invalidEntries.joined(separator: ", "))")
            }
            
            // Return nil only if we have no valid selections at all
            return selections.isEmpty ? nil : CollectionAvatar.AvatarData(
                selections: selections,
                customizations: customizations,
                lastCustomizedAt: lastCustomizedAt,
                customizationVersion: customizationVersion
            )
        }
    }
    
    // MARK: - Initialization
    init(collectionId: String, 
         avatarData: AvatarData, 
         createdAt: Date, 
         isOwner: Bool, 
         version: Version = .current,
         lastModifiedAt: Date? = nil,
         isPublic: Bool = false,
         metadata: [String: String] = [:],
         tags: [String] = [],
         status: Status = .active) {
        self.collectionId = collectionId
        self.avatarData = avatarData
        self.createdAt = createdAt
        self.isOwner = isOwner
        self.version = version
        self.lastModifiedAt = lastModifiedAt ?? createdAt
        self.isPublic = isPublic
        self.metadata = metadata
        self.tags = tags
        self.status = status
    }
    
    // MARK: - Firestore Serialization
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "avatarData": avatarData.toFirestoreDict(),
            "createdAt": Timestamp(date: createdAt),
            "isOwner": isOwner,
            "version": version.rawValue,
            "lastModifiedAt": Timestamp(date: lastModifiedAt),
            "isPublic": isPublic,
            "metadata": metadata,
            "tags": tags,
            "status": status.rawValue
        ]
        
        return data
    }
    
    static func fromFirestore(_ data: [String: Any]) -> CollectionAvatar? {
        guard let collectionId = data["collectionId"] as? String,
              !collectionId.isEmpty else {
            print("❌ Missing or empty collectionId")
            return nil
        }
        
        guard let avatarDataDict = data["avatarData"] as? [String: Any] else {
            print("❌ Missing avatarData")
            return nil
        }
        
        // Handle timestamp with type safety
        let createdAt: Date
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        } else if let date = data["createdAt"] as? Date {
            createdAt = date
        } else {
            print("❌ Invalid createdAt type. Expected Timestamp or Date")
            return nil
        }
        
        // Handle isOwner with type safety
        let isOwner: Bool
        if let boolValue = data["isOwner"] as? Bool {
            isOwner = boolValue
        } else if let intValue = data["isOwner"] as? Int {
            isOwner = intValue != 0
        } else if let stringValue = data["isOwner"] as? String {
            isOwner = stringValue.lowercased() == "true"
        } else {
            print("❌ Invalid isOwner type. Expected Bool, Int, or String")
            return nil
        }
        
        // Get version with type safety
        let version: Version
        if let versionInt = data["version"] as? Int {
            if let parsedVersion = Version(rawValue: versionInt) {
                version = parsedVersion
            } else {
                print("⚠️ Unknown version \(versionInt) in Firestore data")
                return nil
            }
        } else if let versionString = data["version"] as? String,
                  let versionInt = Int(versionString),
                  let parsedVersion = Version(rawValue: versionInt) {
            version = parsedVersion
        } else {
            print("⚠️ Invalid version type or value. Defaulting to v1")
            version = .v1
        }
        
        // Handle new fields with defaults
        let lastModifiedAt: Date
        if let timestamp = data["lastModifiedAt"] as? Timestamp {
            lastModifiedAt = timestamp.dateValue()
        } else if let date = data["lastModifiedAt"] as? Date {
            lastModifiedAt = date
        } else {
            lastModifiedAt = createdAt
        }
        
        let isPublic: Bool
        if let boolValue = data["isPublic"] as? Bool {
            isPublic = boolValue
        } else if let intValue = data["isPublic"] as? Int {
            isPublic = intValue != 0
        } else if let stringValue = data["isPublic"] as? String {
            isPublic = stringValue.lowercased() == "true"
        } else {
            isPublic = false
        }
        
        let metadata: [String: String]
        if let dict = data["metadata"] as? [String: String] {
            metadata = dict
        } else if let dict = data["metadata"] as? [String: Any] {
            metadata = dict.compactMapValues { value in
                if let string = value as? String {
                    return string
                } else if let int = value as? Int {
                    return String(int)
                } else if let bool = value as? Bool {
                    return String(bool)
                }
                return nil
            }
        } else {
            metadata = [:]
        }
        
        let tags: [String]
        if let array = data["tags"] as? [String] {
            tags = array
        } else if let array = data["tags"] as? [Any] {
            tags = array.compactMap { value in
                if let string = value as? String {
                    return string
                } else if let int = value as? Int {
                    return String(int)
                }
                return nil
            }
        } else {
            tags = []
        }
        
        let status: Status
        if let statusString = data["status"] as? String,
           let parsedStatus = Status(rawValue: statusString) {
            status = parsedStatus
        } else {
            status = .active
        }
        
        guard let avatarData = AvatarData.fromFirestoreDict(avatarDataDict, version: version) else {
            print("❌ Failed to parse avatarData")
            return nil
        }
        
        print("✅ Successfully parsed CollectionAvatar: \(collectionId)")
        return CollectionAvatar(
            collectionId: collectionId,
            avatarData: avatarData,
            createdAt: createdAt,
            isOwner: isOwner,
            version: version,
            lastModifiedAt: lastModifiedAt,
            isPublic: isPublic,
            metadata: metadata,
            tags: tags,
            status: status
        )
    }
    
    // MARK: - Migration
    /// Migrates the avatar data to the latest version if needed
    func migrateToLatestVersion() -> CollectionAvatar {
        guard version != .current else { return self }
        
        // Add migration logic here when new versions are added
        switch version {
        case .v1:
            // Already at latest version
            return self
        case .v2:
            // Example of how to handle migration to a newer version
            // Add migration logic here when needed
            return self
        }
    }
    
    // MARK: - Firestore Path
    static func getPath(for collectionId: String, isOwner: Bool) -> String {
        let type = isOwner ? "owned" : "shared"
        return "collections/\(type)/\(type)/\(collectionId)"
    }
}
