import UserNotifications

/// Notification Service Extension — intercepts push notifications before display.
/// Use cases:
/// - Attach rich media (profile photos, reel thumbnails) from URLs in the payload
/// - Decrypt end-to-end encrypted message content
/// - Modify notification title/body based on payload data
class NotificationService: UNNotificationServiceExtension {
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = request.content.mutableCopy() as? UNMutableNotificationContent

        guard let content = bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        let userInfo = content.userInfo

        // Always set categoryIdentifier so action buttons appear correctly.
        // The backend sends `category` at the top level alongside `aps.category`;
        // if aps.category already set it we reinforce it, otherwise we derive it.
        let notifType = userInfo["type"] as? String ?? ""
        let backendCategory = userInfo["category"] as? String

        let resolvedCategory: String? = backendCategory ?? {
            switch notifType {
            case "new_message", "message", "chat":       return "MESSAGE"
            case "new_match", "match":                   return "MATCH"
            case "like", "super_like":                   return "LIKE"
            case "reel_message", "reel", "reel_like",
                 "reel_comment", "reel_reply":           return "REEL"
            default:                                     return nil
            }
        }()

        if let cat = resolvedCategory {
            content.categoryIdentifier = cat
        }

        // Enrich title for chat/reel messages with sender name if available
        if let senderName = userInfo["sender_name"] as? String, !senderName.isEmpty {
            switch notifType {
            case "new_message", "message", "chat", "reel_message":
                content.title = senderName
            default: break
            }
        }

        // Attach profile photo / media thumbnail — runs async; always calls contentHandler
        if let imageURLString = userInfo["image_url"] as? String,
           let imageURL = URL(string: imageURLString) {
            downloadAttachment(from: imageURL, type: "image") { attachment in
                if let attachment {
                    content.attachments = [attachment]
                }
                contentHandler(content)
            }
        } else {
            contentHandler(content)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        // Deliver whatever we have before the system kills us (30s limit)
        if let contentHandler, let content = bestAttemptContent {
            contentHandler(content)
        }
    }

    // MARK: - Attachment Download

    private func downloadAttachment(
        from url: URL,
        type: String,
        completion: @escaping (UNNotificationAttachment?) -> Void
    ) {
        let task = URLSession.shared.downloadTask(with: url) { localURL, response, error in
            guard let localURL, error == nil else {
                completion(nil)
                return
            }

            // Determine file extension from response
            let ext: String
            if let mimeType = (response as? HTTPURLResponse)?.mimeType {
                switch mimeType {
                case "image/png": ext = "png"
                case "image/gif": ext = "gif"
                case "image/webp": ext = "webp"
                default: ext = "jpg"
                }
            } else {
                ext = "jpg"
            }

            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent("\(UUID().uuidString).\(ext)")

            do {
                try FileManager.default.moveItem(at: localURL, to: fileURL)
                let attachment = try UNNotificationAttachment(
                    identifier: type,
                    url: fileURL,
                    options: nil
                )
                completion(attachment)
            } catch {
                completion(nil)
            }
        }
        task.resume()
    }
}
