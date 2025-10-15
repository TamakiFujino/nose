import Foundation
import GooglePlaces

class PlacesCacheManager {
    static let shared = PlacesCacheManager()
    
    // Configuration for API usage optimization
    struct Config {
        static let maxPhotosPerPlace = 5
        static let maxPhotosPerCell = 1
        static let photoCacheSize = 100 // Maximum number of cached photos
    }
    
    private var placeCache: [String: GMSPlace] = [:]
    private var photoCache: [String: UIImage] = [:]
    private let cacheQueue = DispatchQueue(label: "places.cache.queue")
    
    private init() {}
    
    // MARK: - Place Caching
    func getCachedPlace(for placeID: String) -> GMSPlace? {
        return cacheQueue.sync {
            return placeCache[placeID]
        }
    }
    
    func cachePlace(_ place: GMSPlace) {
        guard let placeID = place.placeID else { return }
        
        cacheQueue.async {
            self.placeCache[placeID] = place
        }
    }
    
    func isPlaceCached(for placeID: String) -> Bool {
        return cacheQueue.sync {
            return placeCache[placeID] != nil
        }
    }
    
    // MARK: - Photo Caching
    func getCachedPhoto(for photoID: String) -> UIImage? {
        return cacheQueue.sync {
            return photoCache[photoID]
        }
    }
    
    func cachePhoto(_ image: UIImage, for photoID: String) {
        cacheQueue.async {
            // Check if we need to remove old photos to maintain cache size
            if self.photoCache.count >= Config.photoCacheSize {
                // Remove oldest photos (simple FIFO approach)
                let keysToRemove = Array(self.photoCache.keys.prefix(self.photoCache.count - Config.photoCacheSize + 1))
                keysToRemove.forEach { self.photoCache.removeValue(forKey: $0) }
            }
            
            self.photoCache[photoID] = image
        }
    }
    
    func isPhotoCached(for photoID: String) -> Bool {
        return cacheQueue.sync {
            return photoCache[photoID] != nil
        }
    }
    
    // MARK: - Cache Management
    func clearCache() {
        cacheQueue.async {
            self.placeCache.removeAll()
            self.photoCache.removeAll()
        }
    }
    
    func removePlaceFromCache(placeID: String) {
        cacheQueue.async {
            self.placeCache.removeValue(forKey: placeID)
        }
    }
    
    func removePhotoFromCache(photoID: String) {
        cacheQueue.async {
            self.photoCache.removeValue(forKey: photoID)
        }
    }
} 