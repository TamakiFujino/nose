import UIKit

// MARK: - Helper Methods

extension CollectionPlacesViewController {

    func createCollectionIconImage(collection: PlaceCollection?, iconName: String? = nil, iconUrl: String? = nil) -> UIImage? {
        let size: CGFloat = 60
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format)

        let finalIconUrl = iconUrl ?? collection?.iconUrl
        let finalIconName = iconName ?? collection?.iconName

        let hasIcon = (finalIconUrl != nil && !finalIconUrl!.isEmpty) || (finalIconName != nil && UIImage(systemName: finalIconName!) != nil)

        if let iconUrlString = finalIconUrl, let _ = URL(string: iconUrlString) {
            return renderer.image { context in
                let rect = CGRect(x: 0, y: 0, width: size, height: size)
                let cgContext = context.cgContext

                let path = UIBezierPath(ovalIn: rect)
                cgContext.setFillColor(hasIcon ? UIColor.white.cgColor : UIColor.systemGray5.cgColor)
                cgContext.addPath(path.cgPath)
                cgContext.fillPath()

                cgContext.setStrokeColor(UIColor.white.cgColor)
                cgContext.setLineWidth(1.5)
                cgContext.addPath(path.cgPath)
                cgContext.strokePath()
            }
        }

        return renderer.image { context in
            let rect = CGRect(x: 0, y: 0, width: size, height: size)
            let cgContext = context.cgContext

            let path = UIBezierPath(ovalIn: rect)
            cgContext.setFillColor(hasIcon ? UIColor.white.cgColor : UIColor.systemGray5.cgColor)
            cgContext.addPath(path.cgPath)
            cgContext.fillPath()

            cgContext.setStrokeColor(UIColor.white.cgColor)
            cgContext.setLineWidth(1.5)
            cgContext.addPath(path.cgPath)
            cgContext.strokePath()

            if let iconName = finalIconName,
               let iconImage = UIImage(systemName: iconName) {
                let iconSize: CGFloat = 33
                let iconRect = CGRect(
                    x: (size - iconSize) / 2,
                    y: (size - iconSize) / 2,
                    width: iconSize,
                    height: iconSize
                )

                let aspect = iconImage.size.width / iconImage.size.height
                var drawRect = iconRect

                if aspect > 1 {
                    let height = iconRect.width / aspect
                    drawRect = CGRect(
                        x: iconRect.origin.x,
                        y: iconRect.origin.y + (iconRect.height - height) / 2,
                        width: iconRect.width,
                        height: height
                    )
                } else {
                    let width = iconRect.height * aspect
                    drawRect = CGRect(
                        x: iconRect.origin.x + (iconRect.width - width) / 2,
                        y: iconRect.origin.y,
                        width: width,
                        height: iconRect.height
                    )
                }

                let tintedIcon = iconImage.withTintColor(.systemGray, renderingMode: .alwaysTemplate)
                tintedIcon.draw(in: drawRect, blendMode: .normal, alpha: 1.0)
            }
        }
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

        if let iconUrl = iconUrlToUse, !iconUrl.isEmpty {
            loadRemoteIconImage(urlString: iconUrl) { [weak self] image in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if let image = image {
                        self.collectionIconImageView.image = self.createIconImageWithBackground(remoteImage: image)
                    } else {
                        self.collectionIconImageView.image = self.createCollectionIconImage(collection: self.collection, iconName: iconNameToUse, iconUrl: nil)
                    }
                }
            }
        } else {
            collectionIconImageView.image = createCollectionIconImage(collection: collection, iconName: iconNameToUse, iconUrl: nil)
        }
    }

    func createIconImageWithBackground(remoteImage: UIImage) -> UIImage? {
        let size: CGFloat = 60
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format)

        return renderer.image { context in
            let rect = CGRect(x: 0, y: 0, width: size, height: size)
            let cgContext = context.cgContext

            let path = UIBezierPath(ovalIn: rect)
            cgContext.setFillColor(UIColor.white.cgColor)
            cgContext.addPath(path.cgPath)
            cgContext.fillPath()

            cgContext.setStrokeColor(UIColor.white.cgColor)
            cgContext.setLineWidth(1.5)
            cgContext.addPath(path.cgPath)
            cgContext.strokePath()

            let imageSize: CGFloat = size * 0.75
            let imageRect = CGRect(
                x: (size - imageSize) / 2,
                y: (size - imageSize) / 2,
                width: imageSize,
                height: imageSize
            )

            cgContext.addPath(path.cgPath)
            cgContext.clip()

            let aspect = remoteImage.size.width / remoteImage.size.height
            var drawRect = imageRect

            if aspect > 1 {
                let height = imageRect.width / aspect
                drawRect = CGRect(
                    x: imageRect.origin.x,
                    y: imageRect.origin.y + (imageRect.height - height) / 2,
                    width: imageRect.width,
                    height: height
                )
            } else {
                let width = imageRect.height * aspect
                drawRect = CGRect(
                    x: imageRect.origin.x + (imageRect.width - width) / 2,
                    y: imageRect.origin.y,
                    width: width,
                    height: imageRect.height
                )
            }

            remoteImage.draw(in: drawRect, blendMode: .normal, alpha: 1.0)
        }
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
