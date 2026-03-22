import UIKit

// MARK: - Helper Methods

extension CollectionPlacesViewController {

    func createCollectionIconImage(collection: PlaceCollection?, iconName: String? = nil, iconUrl: String? = nil) -> UIImage? {
        let finalIconUrl = iconUrl ?? collection?.iconUrl
        let finalIconName = iconName ?? collection?.iconName
        let legacyImage = finalIconName == nil ? imageForCollectionIconURL(finalIconUrl) : nil

        return CollectionIconRenderer.makeIconImage(
            iconName: finalIconName,
            remoteImage: legacyImage,
            size: 60
        )
    }

    func loadRemoteIconImage(urlString: String, completion: @escaping (UIImage?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }

        if let cachedImage = CollectionPlacesViewController.imageCache.object(forKey: urlString as NSString) {
            completion(cachedImage)
            return
        }

        let request = URLRequest(url: url)
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                  let image = UIImage(data: data) else {
                completion(nil)
                return
            }

            CollectionPlacesViewController.imageCache.setObject(image, forKey: urlString as NSString)
            completion(image)
        }.resume()
    }

    func updateCollectionIconDisplay() {
        let iconUrlToUse = currentIconUrl ?? collection.iconUrl
        let iconNameToUse = currentIconName ?? collection.iconName

        if let iconName = iconNameToUse, !iconName.isEmpty {
            collectionIconImageView.image = createCollectionIconImage(collection: collection, iconName: iconName, iconUrl: nil)
            return
        }

        if let iconUrl = iconUrlToUse, !iconUrl.isEmpty {
            loadRemoteIconImage(urlString: iconUrl) { [weak self] image in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.collectionIconImageView.image = CollectionIconRenderer.makeIconImage(
                        iconName: nil,
                        remoteImage: image,
                        size: 60
                    )
                }
            }
            return
        }

        collectionIconImageView.image = createCollectionIconImage(collection: collection, iconName: nil, iconUrl: nil)
    }

    func createIconImageWithBackground(remoteImage: UIImage) -> UIImage? {
        CollectionIconRenderer.makeIconImage(iconName: nil, remoteImage: remoteImage, size: 60)
    }

    private func imageForCollectionIconURL(_ urlString: String?) -> UIImage? {
        guard let urlString, !urlString.isEmpty else {
            return nil
        }
        return CollectionPlacesViewController.imageCache.object(forKey: urlString as NSString)
    }

    // MARK: - Avatar Loading

    @objc func handleAvatarThumbnailUpdatedNotification(_ note: Notification) {
        guard let updatedCollectionId = note.userInfo?["collectionId"] as? String,
              updatedCollectionId == collection.id else { return }
        loadOverlappingAvatars()
    }

    func loadAvatarThumbnail(forceRefresh: Bool) {
        let cacheKey = NSString(string: collection.id)
        if !forceRefresh, let cached = CollectionPlacesViewController.imageCache.object(forKey: cacheKey) {
            avatarImageView.image = cached
            return
        }

        CollectionDataService.shared.fetchAvatarThumbnailURL(ownerId: collection.userId, collectionId: collection.id) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let thumbnailData):
                guard let thumbnailData = thumbnailData else {
                    self.loadAvatarThumbnailFromCachesFallback()
                    return
                }
                var urlString = thumbnailData.url
                if let baseURL = URL(string: urlString), let ts = thumbnailData.timestamp {
                    var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
                    var q = comps?.queryItems ?? []
                    q.append(URLQueryItem(name: "t", value: "\(Int(ts.dateValue().timeIntervalSince1970))"))
                    comps?.queryItems = q
                    urlString = comps?.url?.absoluteString ?? urlString
                }
                guard let finalURL = URL(string: urlString) else {
                    self.loadAvatarThumbnailFromCachesFallback()
                    return
                }
                self.downloadImage(from: finalURL, ignoreCache: true) { image in
                    DispatchQueue.main.async {
                        if let image = image {
                            CollectionPlacesViewController.imageCache.setObject(image, forKey: cacheKey)
                            self.avatarImageView.image = image
                        } else {
                            self.loadAvatarThumbnailFromCachesFallback()
                        }
                    }
                }
            case .failure:
                self.loadAvatarThumbnailFromCachesFallback()
            }
        }
    }

    func loadAvatarThumbnailFromCachesFallback() {
        let relativePath = "avatar_captures/users/\(collection.userId)/collections/\(collection.id)/avatar.png"
        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let fileURL = cachesDirectory.appendingPathComponent(relativePath)
        if FileManager.default.fileExists(atPath: fileURL.path), let image = UIImage(contentsOfFile: fileURL.path) {
            CollectionPlacesViewController.imageCache.setObject(image, forKey: NSString(string: collection.id))
            avatarImageView.image = image
        } else {
            if avatarImageView.image == nil {
                avatarImageView.image = UIImage(named: "AvatarPlaceholder") ?? UIImage(systemName: "person.crop.circle")
                avatarImageView.contentMode = .scaleAspectFit
            }
        }
    }

    func prefillAvatarImageIfCached() {
        let cacheKey = NSString(string: collection.id)
        if let cached = CollectionPlacesViewController.imageCache.object(forKey: cacheKey) {
            avatarImageView.image = cached
            return
        }
        let relativePath = "avatar_captures/users/\(collection.userId)/collections/\(collection.id)/avatar.png"
        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let fileURL = cachesDirectory.appendingPathComponent(relativePath)
        if FileManager.default.fileExists(atPath: fileURL.path), let image = UIImage(contentsOfFile: fileURL.path) {
            CollectionPlacesViewController.imageCache.setObject(image, forKey: cacheKey)
            avatarImageView.image = image
        }
    }

    func downloadImage(from url: URL, ignoreCache: Bool = false, completion: @escaping (UIImage?) -> Void) {
        var request = URLRequest(url: url)
        if ignoreCache {
            request.cachePolicy = .reloadIgnoringLocalCacheData
        }
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data, let image = UIImage(data: data) {
                completion(image)
            } else {
                completion(nil)
            }
        }.resume()
    }

    func loadOverlappingAvatars() {
        avatarsLoadGeneration += 1
        let currentGen = avatarsLoadGeneration
        avatarsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let ownerId = collection.userId
        let collectionId = collection.id
        let thumbSize: CGFloat = 216

        func renderSquare(image: UIImage?) -> UIImage? {
            guard let img = image else { return nil }
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = UIScreen.main.scale
            format.opaque = false
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: thumbSize, height: thumbSize), format: format)
            let output = renderer.image { ctx in
                UIColor.clear.setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: thumbSize, height: thumbSize))
                let iw = img.size.width
                let ih = img.size.height
                if iw <= 0 || ih <= 0 { return }
                let scale = min(thumbSize / iw, thumbSize / ih)
                let drawW = iw * scale
                let drawH = ih * scale
                let dx = (thumbSize - drawW) * 0.5
                let dy = (thumbSize - drawH) * 0.5
                img.draw(in: CGRect(x: dx, y: dy, width: drawW, height: drawH))
            }
            return output
        }

        func addAvatar(image: UIImage?) {
            if currentGen != avatarsLoadGeneration { return }
            let source = image ?? UIImage(named: "AvatarPlaceholder")
            let processed = renderSquare(image: source)
            let iv = UIImageView(image: processed)
            iv.translatesAutoresizingMaskIntoConstraints = false
            iv.contentMode = .scaleAspectFill
            iv.clipsToBounds = true
            iv.layer.cornerRadius = thumbSize / 2
            iv.layer.borderColor = UIColor.clear.cgColor
            iv.layer.borderWidth = 0
            iv.layer.contentsScale = UIScreen.main.scale
            iv.layer.magnificationFilter = .linear
            iv.layer.minificationFilter = .trilinear
            NSLayoutConstraint.activate([
                iv.widthAnchor.constraint(equalToConstant: thumbSize),
                iv.heightAnchor.constraint(equalToConstant: thumbSize)
            ])
            avatarsStackView.addArrangedSubview(iv)
        }

        CollectionDataService.shared.fetchOrderedMembers(ownerId: ownerId, collectionId: collectionId) { [weak self] result in
            guard let self = self, case .success(let orderedIds) = result, !orderedIds.isEmpty else { return }

            let group = DispatchGroup()
            for uid in orderedIds {
                group.enter()
                CollectionDataService.shared.fetchAvatarThumbnailURL(ownerId: uid, collectionId: collectionId) { [weak self] thumbResult in
                    guard let self = self else { group.leave(); return }
                    if case .success(let thumbnailData) = thumbResult, let data = thumbnailData, let url = URL(string: data.url) {
                        self.downloadImage(from: url, ignoreCache: true) { image in
                            DispatchQueue.main.async {
                                if currentGen == self.avatarsLoadGeneration { addAvatar(image: image) }
                                group.leave()
                            }
                        }
                    } else {
                        DispatchQueue.main.async {
                            if currentGen == self.avatarsLoadGeneration { addAvatar(image: nil) }
                            group.leave()
                        }
                    }
                }
            }
        }
    }
}
