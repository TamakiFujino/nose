//
//  ShareViewController.swift
//  OpenInNose
//
//  Created by Tamaki Fujino on 2025/09/29.
//

import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers

@objc(ShareViewController)
public class ShareViewController: SLComposeServiceViewController {

    public override func isContentValid() -> Bool {
        return true
    }

    public override func didSelectPost() {
        handleShare()
    }

    public override func configurationItems() -> [Any]! {
        return []
    }

    private func handleShare() {
        guard let items = self.extensionContext?.inputItems as? [NSExtensionItem] else {
            complete(); return
        }
        // Try attachments first
        for item in items {
            if let attachments = item.attachments {
                for provider in attachments {
                    if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                        provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (item, _) in
                            if let url = item as? URL { self?.openInHost(with: url) } else { self?.complete() }
                        }
                        return
                    }
                    if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                        provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { [weak self] (item, _) in
                            if let text = item as? String, let url = URL(string: text) { self?.openInHost(with: url) } else { self?.complete() }
                        }
                        return
                    }
                }
            }
        }
        // Fallback: use composed text
        if let text = self.contentText, let url = URL(string: text) {
            openInHost(with: url)
        } else {
            complete()
        }
    }

    private func openInHost(with sharedURL: URL) {
        // Try to extract placeId from the shared URL
        let placeId = extractPlaceId(from: sharedURL)
        var target: URL?
        if let pid = placeId {
            target = URL(string: "nose://open?placeId=\(pid)")
        } else {
            // Pass the original URL through if we can't extract yet
            let encoded = sharedURL.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? sharedURL.absoluteString
            target = URL(string: "nose://open?url=\(encoded)")
        }
        
        if let target = target {
            // Use extension-safe open via NSExtensionContext
            if let ctx = self.extensionContext {
                ctx.open(target) { success in
                    DispatchQueue.main.async {
                        if !success {
                            print("[ShareExtension] Failed to open URL: \(target.absoluteString)")
                        }
                        self.complete()
                    }
                }
            } else {
                complete()
            }
        } else {
            complete()
        }
    }

    private func extractPlaceId(from url: URL) -> String? {
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let q = components.queryItems?.first(where: { $0.name == "q" })?.value,
           q.lowercased().hasPrefix("place_id:") {
            return String(q.dropFirst("place_id:".count))
        }
        let path = url.absoluteString
        if let range = path.range(of: "!1s") {
            let tail = path[range.upperBound...]
            if let end = tail.firstIndex(of: "!") {
                let pid = String(tail[..<end])
                if pid.hasPrefix("ChI") { return pid }
            }
        }
        return nil
    }

    private func complete() {
        self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}
