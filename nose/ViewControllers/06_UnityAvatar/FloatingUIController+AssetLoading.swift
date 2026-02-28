import UIKit
import FirebaseCore

// MARK: - Asset Loading & Remote Resources
extension FloatingUIController {

    func loadAssetData() {
        // Prefer loading from Addressables catalog on Hosting
        loadAssetsFromAddressablesCatalog { [weak self] in
            guard let self else { return }
            self.updateThumbnailsForCategory()
            // Ensure pose + all saved selections are applied on first load (even if default tab is clothes)
            self.applyAllSelectionsToUnity()
        }
    }

    func loadAssetsForCategory(_ category: String, completion: (() -> Void)? = nil) {
        // Try Firebase Hosting first
        if let baseURLString = hostingBaseURL(),
           let url = URL(string: baseURLString + "/assets_\(category.lowercased()).json") {
            let task = URLSession.shared.dataTask(with: url) { data, response, error in
                if let error = error {
                    Logger.log("Network error loading assets for \(category): \(error)", level: .error, category: "FloatingUI")
                    self.loadAssetsFromBundle(category: category)
                    DispatchQueue.main.async { completion?() }
                    return
                }
                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                    Logger.log("Invalid HTTP response for \(category): \((response as? HTTPURLResponse)?.statusCode ?? -1)", level: .error, category: "FloatingUI")
                    self.loadAssetsFromBundle(category: category)
                    DispatchQueue.main.async { completion?() }
                    return
                }
                guard let data = data else {
                    Logger.log("Empty data for \(category)", level: .error, category: "FloatingUI")
                    self.loadAssetsFromBundle(category: category)
                    DispatchQueue.main.async { completion?() }
                    return
                }

                do {
                    let categoryAssets = try JSONDecoder().decode(CategoryAssets.self, from: data)
                    let mainCategory = categoryAssets.category
                    if self.assetData[mainCategory] == nil { self.assetData[mainCategory] = [:] }
                    for asset in categoryAssets.assets {
                        var existing = self.assetData[mainCategory]![asset.subcategory] ?? []
                        if !existing.contains(where: { $0.id == asset.id }) {
                            existing.append(asset)
                        }
                        self.assetData[mainCategory]![asset.subcategory] = existing
                    }
                } catch {
                    Logger.log("JSON decode error for \(category): \(error)", level: .error, category: "FloatingUI")
                    self.loadAssetsFromBundle(category: category)
                }
                DispatchQueue.main.async { completion?() }
            }
            task.resume()
            return
        }

        // Fallback to bundled JSON if hosting URL is not available
        loadAssetsFromBundle(category: category)
        completion?()
    }

    private func loadAssetsFromBundle(category: String) {
        guard let url = Bundle.main.url(forResource: "assets_\(category.lowercased())", withExtension: "json") else {
            Logger.log("Could not find bundled assets JSON for category: \(category)", level: .warn, category: "FloatingUI")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let categoryAssets = try JSONDecoder().decode(CategoryAssets.self, from: data)
            let mainCategory = categoryAssets.category
            if assetData[mainCategory] == nil { assetData[mainCategory] = [:] }
            for asset in categoryAssets.assets {
                var existing = assetData[mainCategory]![asset.subcategory] ?? []
                if !existing.contains(where: { $0.id == asset.id }) {
                    existing.append(asset)
                }
                assetData[mainCategory]![asset.subcategory] = existing
            }
        } catch {
            Logger.log("Error loading bundled assets for \(category): \(error)", level: .error, category: "FloatingUI")
        }
    }

    func refetchAssetsForSelectedCategory() {
        // Reload from Addressables catalog, then refresh UI for selected category
        loadAssetsFromAddressablesCatalog { [weak self] in
            self?.updateThumbnailsForCategory()
        }
    }

    private func addressablesCatalogURL() -> URL? {
        // Prefer explicit URL in Config.plist
        if let filePath = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let plistDict = NSDictionary(contentsOfFile: filePath) as? [String: Any],
           let explicitURL = plistDict["AddressablesCatalogURL"] as? String,
           !explicitURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let url = URL(string: explicitURL.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return url
        }
        // Default to Firebase Hosting base + standard iOS catalog path
        if let base = hostingBaseURL(), let url = URL(string: base + "/addressables/iOS/catalog_0.1.json") {
            return url
        }
        return nil
    }

    private func loadAssetsFromAddressablesCatalog(completion: @escaping () -> Void) {
        guard let url = addressablesCatalogURL() else {
            Logger.log("Addressables catalog URL not available.", level: .error, category: "FloatingUI")
            completion()
            return
        }
        URLSession.shared.dataTask(with: url) { data, response, error in
            defer { DispatchQueue.main.async { completion() } }
            if let error = error {
                Logger.log("Failed to load addressables catalog: \(error)", level: .error, category: "FloatingUI")
                return
            }
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                Logger.log("Invalid HTTP response for catalog: \((response as? HTTPURLResponse)?.statusCode ?? -1)", level: .error, category: "FloatingUI")
                return
            }
            guard let data = data else {
                Logger.log("Empty catalog data", level: .error, category: "FloatingUI")
                return
            }
            do {
                // Parse m_InternalIds as [String]
                guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                      let internalIds = json["m_InternalIds"] as? [String] else {
                    Logger.log("Catalog format unexpected (m_InternalIds not found)", level: .error, category: "FloatingUI")
                    return
                }
                self.rebuildAssetDataFromCatalog(internalIds: internalIds)
            } catch {
                Logger.log("Catalog JSON parse error: \(error)", level: .error, category: "FloatingUI")
            }
        }.resume()
    }

    private func rebuildAssetDataFromCatalog(internalIds: [String]) {
        var newAssetData: [String: [String: [AssetItem]]] = [:]
        let modelPrefix = "Assets/Models/"

        for id in internalIds where id.hasPrefix(modelPrefix) {
            // e.g., Assets/Models/Clothes/Tops/01_tops_tight_short.prefab
            let relative = String(id.dropFirst(modelPrefix.count))
            let parts = relative.split(separator: "/").map(String.init)
            guard parts.count >= 3 else { continue }
            let category = parts[0]
            let subcategory = parts[1]
            let filename = parts.last ?? ""
            let name = (filename as NSString).deletingPathExtension

            // Convert internal id (Assets/Models/.../Name.prefab) to Addressables address (Models/.../Name)
            let modelPath = "Models/\(category)/\(subcategory)/\(name)"

            // Compose remote thumbnail URL on Hosting under /Thumbs/{Category}/{Subcategory}/{Name}.jpg
            var thumbURLString: String? = nil
            if let base = hostingBaseURL() {
                var thumbURL = URL(string: base)
                thumbURL?.appendPathComponent("Thumbs")
                thumbURL?.appendPathComponent(category)
                thumbURL?.appendPathComponent(subcategory)
                thumbURL?.appendPathComponent("\(name).jpg")
                thumbURLString = thumbURL?.absoluteString
            }

            let item = AssetItem(
                id: "\(category)_\(subcategory)_\(name)",
                name: name,
                modelPath: modelPath,
                thumbnailPath: thumbURLString,
                category: category,
                subcategory: subcategory,
                isActive: true,
                metadata: nil
            )
            if newAssetData[category] == nil { newAssetData[category] = [:] }
            var list = newAssetData[category]![subcategory] ?? []
            if !list.contains(where: { $0.id == item.id }) { list.append(item) }
            newAssetData[category]![subcategory] = list
        }

        DispatchQueue.main.async {
            self.assetData = newAssetData
        }
    }

    // MARK: - URL Resolution

    func hostingBaseURL() -> String? {
        // 1) Prefer explicit base URL in Config.plist (key: FirebaseHostingBaseURL)
        if let filePath = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let plistDict = NSDictionary(contentsOfFile: filePath) as? [String: Any],
           let explicitURL = plistDict["FirebaseHostingBaseURL"] as? String,
           !explicitURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return explicitURL.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // 2) Derive from Firebase project ID (https://{projectID}.web.app)
        if let projectID = FirebaseApp.app()?.options.projectID, !projectID.isEmpty {
            return "https://\(projectID).web.app"
        }

        // 3) No hosting base URL available
        return nil
    }

    private func colorPaletteURL() -> URL? {
        // Prefer explicit URL in Config.plist (key: ColorPaletteURL)
        if let filePath = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let plistDict = NSDictionary(contentsOfFile: filePath) as? [String: Any],
           let explicit = plistDict["ColorPaletteURL"] as? String,
           !explicit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let url = URL(string: explicit.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return url
        }
        // Default to Firebase Hosting base + /palettes/default.json
        if let base = hostingBaseURL(), let url = URL(string: base + "/palettes/default.json") {
            return url
        }
        return nil
    }

    func loadColorPalette() {
        guard let baseURL = colorPaletteURL() else { return }
        // Add a cache-busting query param and ignore local cache
        var finalURL = baseURL
        if var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) {
            var items = comps.queryItems ?? []
            items.append(URLQueryItem(name: "ts", value: String(Int(Date().timeIntervalSince1970))))
            comps.queryItems = items
            finalURL = comps.url ?? baseURL
        }
        let request = URLRequest(url: finalURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                Logger.log("Failed to load color palette: \(error)", level: .error, category: "FloatingUI")
                return
            }
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode), let data = data else { return }
            do {
                // Accept either ["#hex", ...] or {"colors":["#hex", ...]}
                if let arr = try JSONSerialization.jsonObject(with: data) as? [String] {
                    DispatchQueue.main.async { self.colorSwatches = arr }
                } else if let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any], let arr = obj["colors"] as? [String] {
                    DispatchQueue.main.async { self.colorSwatches = arr }
                }
            } catch {
                Logger.log("Palette JSON parse error: \(error)", level: .error, category: "FloatingUI")
            }
        }.resume()
    }

    private func environmentPrefix() -> String? {
        if let env = Bundle.main.object(forInfoDictionaryKey: "NoseEnvironment") as? String {
            if env.caseInsensitiveCompare("Development") == .orderedSame { return "dev" }
            if env.caseInsensitiveCompare("Staging") == .orderedSame { return "staging" }
            if env.caseInsensitiveCompare("Production") == .orderedSame { return "staging" }
        }
        return nil
    }

    // MARK: - Thumbnail URL Resolution

    func resolvedThumbnailURL(for asset: AssetItem) -> URL? {
        guard let base = hostingBaseURL() else { return nil }
        // Compose: {base}/Thumbs/{Category}/{Subcategory}/{Name}.jpg
        var url = URL(string: base)
        url?.appendPathComponent("Thumbs")
        url?.appendPathComponent(asset.category)
        url?.appendPathComponent(asset.subcategory)
        url?.appendPathComponent("\(asset.name).jpg")
        return url
    }

    func resolvedRemoteURL(from path: String) -> URL? {
        let lower = path.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
            return URL(string: path)
        }
        // Treat as relative to hosting base (handle with or without leading slash)
        guard let base = hostingBaseURL() else { return nil }
        var url = URL(string: base)
        // Ensure no duplicate slashes
        let trimmed = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        for comp in trimmed.split(separator: "/") {
            url?.appendPathComponent(String(comp))
        }
        return url
    }

    func thumbnailURLCandidates(from url: URL) -> [URL] {
        var candidates: [URL] = [url]
        let last = url.lastPathComponent.lowercased()
        if last.hasSuffix(".jpg") {
            let alt = url.deletingLastPathComponent().appendingPathComponent((url.lastPathComponent as NSString).deletingPathExtension + ".png")
            candidates.append(alt)
        } else if last.hasSuffix(".png") {
            let alt = url.deletingLastPathComponent().appendingPathComponent((url.lastPathComponent as NSString).deletingPathExtension + ".jpg")
            candidates.append(alt)
        } else {
            candidates.append(url.appendingPathExtension("jpg"))
            candidates.append(url.appendingPathExtension("png"))
        }
        return candidates
    }

    // MARK: - Remote Image Loading

    func setRemoteImage(on button: UIButton, urls: [URL], index: Int) {
        let placeholder = UIImage(systemName: "photo")
        if button.image(for: .normal) == nil {
            button.setImage(placeholder, for: .normal)
            button.tintColor = .lightGray
        }
        // Cache check by first candidate URL key
        if let key = urls.first?.absoluteString as NSString?, let cached = imageCache.object(forKey: key) {
            button.setImage(cached, for: .normal)
            button.tintColor = .clear
            return
        }
        attemptFetch(urls: urls, at: 0, button: button, index: index)
    }

    private func attemptFetch(urls: [URL], at position: Int, button: UIButton, index: Int) {
        guard position < urls.count else { return }
        let url = urls[position]
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            let httpCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            if error != nil || !(200...299).contains(httpCode) || data == nil {
                self?.attemptFetch(urls: urls, at: position + 1, button: button, index: index)
                return
            }
            if let data = data, let image = UIImage(data: data) {
                guard let self = self else { return }
                let normalized = self.normalizeImageForDisplay(image)
                if let key = urls.first?.absoluteString as NSString? {
                    self.imageCache.setObject(normalized, forKey: key)
                }
                DispatchQueue.main.async {
                    if button.tag == index {
                        button.setImage(normalized, for: .normal)
                        button.tintColor = .clear
                    }
                }
            }
        }.resume()
    }

    func normalizeImageForDisplay(_ image: UIImage) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        format.opaque = false
        format.preferredRange = .standard
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
        return rendered.withRenderingMode(.alwaysOriginal)
    }
}
